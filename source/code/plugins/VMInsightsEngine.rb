# frozen_string_literal: true

module VMInsights

    require_relative 'VMInsightsDataCollector.rb'

    class MetricsEngine

        require 'json'
        require 'thread'

        def initialize
            @thread = nil
        end

        def start(config, &cb)
            raise ArgumentError, 'config is nil' if config.nil?
            raise ArgumentError, "config is not kind of #{Configuration}" unless config.kind_of? Configuration
            raise ArgumentError, 'proc required' if cb.nil?
            raise RuntimeError, 'already started' unless @thread.nil?
            @thread = PollingThread.new config.poll_interval, config.computer, config.log, config.data_collector, cb
            nil
        end

        def stop
            return if @thread.nil?
            @thread = nil if @thread.stop
        end

        def running?
            (! @thread.nil?) && @thread.status
        end

        class Configuration
            def initialize(computer, log, data_collector)
                raise ArgumentError unless log
                raise ArgumentError, "#{data_collector.class.name}" unless data_collector.kind_of? IDataCollector
                @poll_interval = 60 # seconds
                @computer = computer
                @data_collector = data_collector
                @log = log
            end

            def poll_interval=(v)
                raise ArgumentError unless (v.kind_of? Numeric) && (v.real?) && (v >= 1)
                @poll_interval = v
            end

            attr_reader :poll_interval, :computer, :data_collector, :log

        end # class Configuration

    private

        class PollingThread < Thread
            def initialize(interval, computer, log, data_collector, cb)
                @mutex = Mutex.new
                @condvar = ConditionVariable.new
                @run = true
                @log = log
                @data_collector = data_collector
                @cb = cb
                @saved_exception = SavedException.new
                @saved_cpu_exception = SavedException.new
                @cummulative_data = CummulativeData.new
                super() {
                    @cummulative_data.initialize_from_baseline @data_collector.baseline
                    MetricTuple.computer computer
                    begin
                        @log.info "Starting polling loop at #{interval} second interval"
                        # try to keep as close to the polling interval, independent of
                        # any delay waking up from the sleep, collecting data, or
                        # emitting the message.
                        expected_wakeup_time = Time.now
                        while @run do
                            expected_wakeup_time += interval
                            now = Time.now
                            if expected_wakeup_time <= now
                                expected_wakeup_time = now
                            else
                                sleep_time = expected_wakeup_time - now
                                @mutex.synchronize {
                                    @condvar.wait(@mutex, sleep_time) if @run
                                }
                            end
                            yield_metrics_message() if @run
                        end
                    ensure
                        @log.info "Stopping polling"
                    end
                }
            end

            def stop
                @mutex.synchronize {
                    @run = false
                    @condvar.broadcast
                }
                self.join(5) || self.terminate
            end

            def yield_metrics_message()
                begin
                    begin #1
                        perf_data = gather_data
                        message = data_to_message perf_data
                        protected_yield message
                    rescue => std
                        @log.error_backtrace std.backtrace
                        @log.error std.message
                    end # begin #1
                rescue SystemCallError => ex
                    return "#{__FILE__}(#{__LINE__}): #{Time.now}" if @saved_exception.same(ex)
                    @log.error ex.message
                    @saved_exception = SavedException.new(ex)
                rescue => std
                    return "#{__FILE__}(#{__LINE__}): #{Time.now}" if @saved_exception.same(std)
                    @log.error std.message
                    @saved_exception = SavedException.new(std)
                end
            end

            def protected_yield(*args)
                @cb[*args]
            rescue => ex
                @log.error "Unexpected exception #{ex.inspect}"
                @log.error_backtrace ex.backtrace
                true    # if there was an exception, assume next steps should happen so as not to have it keep happening
            end

            def gather_data
                @log.debug "Gather Data"    # Don't delete, used in unit test
                data = Array.new
                start_sample
                [
                    :liveness,
                    :available_memory_mb,
                    :processor,
                    :logical_disks,
                    :network,
                ].each { |method|
                    begin
                        send(method) { |me| data << me }
                    rescue IDataCollector::Unavailable => un
                        @log.debug "#{method}: #{un.message}"
                        @log.debug_backtrace un.backtrace
                    rescue => ex
                        @log.error "Unexpected exception #{ex.inspect}"
                        @log.error_backtrace ex.backtrace
                    end
                }
                end_sample
                return data
            rescue SystemCallError => sce
                @log.error sce.message
                @log.debug_backtrace
            rescue NoMemoryError, StandardError => ex
                @log.error ex.message
                @log.debug_backtrace
            end

            def data_to_message(data)
                data
            end

            def start_sample
                @data_collector.start_sample
            end

            def liveness
                yield MetricTuple.factory "Computer", "Heartbeat", 1
                nil
            end

            def available_memory_mb
                free, total = @data_collector.get_available_memory_kb
                free = mb_from_kb free
                total = mb_from_kb total
                yield MetricTuple.factory "Memory", "AvailableMB", free, { "#{MetricTuple::Origin}/memorySizeMB" => total }
                nil
            end

            def processor
                total_time, idle = @data_collector.get_cpu_idle
                total_time, idle = @cummulative_data.get_cpu_time_delta total_time, idle
                raise IDataCollector::Unavailable.new "total time delta is zero" if total_time.zero?

                begin
                    cpus =  @data_collector.get_number_of_cpus
                    yield MetricTuple.factory "Processor", "UtilizationPercentage",
                                    100.0 * (1.0 - ((idle * 1.0) / (total_time * 1.0))),
                                    { "#{MetricTuple::Origin}/totalCpus" => cpus }
                rescue => ex
                    unless @saved_cpu_exception.same(ex)
                        @log.error ex.message
                        @log.debug_backtrace
                        @saved_cpu_exception = SavedException.new(ex)
                    end
                end
                nil
            end

            def logical_disks
                @data_collector.get_filesystems.each { |fs|
                    common_tag = { "#{MetricTuple::Origin}/mountId" => fs.mount_point }
                    yield MetricTuple.factory "LogicalDisk", "Status", 1, common_tag
                    yield MetricTuple.factory "LogicalDisk", "FreeSpacePercentage", (100.0 * fs.free_space_in_bytes) / fs.size_in_bytes, common_tag
                    yield MetricTuple.factory "LogicalDisk", "FreeSpaceMB",
                                        fs.free_space_in_bytes / (1024 * 1024),
                                        common_tag.merge({"#{MetricTuple::Origin}/diskSizeMB" => fs.size_in_bytes / (1024 * 1024)})
                    begin
                        perf = @data_collector.get_disk_stats(fs.device_name)
                        delta_time = perf.delta_time.to_f
                        reads = perf.reads
                        writes = perf.writes
                        yield MetricTuple.factory "LogicalDisk", "ReadsPerSecond", (reads / delta_time), common_tag unless reads.nil?
                        yield MetricTuple.factory "LogicalDisk", "WritesPerSecond", (writes / delta_time), common_tag unless writes.nil?
                        yield MetricTuple.factory "LogicalDisk", "TransfersPerSecond", ((reads + writes) / delta_time), common_tag unless (reads.nil? || writes.nil?)
                        reads = perf.bytes_read
                        writes = perf.bytes_written
                        yield MetricTuple.factory "LogicalDisk", "ReadBytesPerSecond", (reads / delta_time), common_tag unless reads.nil?
                        yield MetricTuple.factory "LogicalDisk", "WriteBytesPerSecond", (writes / delta_time), common_tag unless writes.nil?
                        yield MetricTuple.factory "LogicalDisk", "BytesPerSecond", ((reads + writes) / delta_time), common_tag unless (reads.nil? || writes.nil?)
                    rescue IDataCollector::Unavailable => un
                        @log.debug "#{fs.device_name}: #{un.message}"
                        @log.debug_backtrace un.backtrace
                    end
                }
                nil
            end

            def network
                @data_collector.get_net_stats.each { |d|
                    yield make_network_metric d.delta_time, d.device, "ReadBytesPerSecond", d.bytes_received
                    yield make_network_metric d.delta_time, d.device, "WriteBytesPerSecond", d.bytes_sent
                }
                nil
            end

            def end_sample
                @data_collector.end_sample
            end

        private

            def make_network_metric(delta_time, dev, name, bytes)
                MetricTuple.factory "Network", name,
                    (bytes.to_f / delta_time.to_f),
                    {
                        "#{MetricTuple::Origin}/networkDeviceId" => dev,
                        "#{MetricTuple::Origin}/bytes" => bytes
                    }
            end

            class SavedException
                def initialize(ex = nil)
                    @ex = ex
                    @timeout = Time.now + (60 * 60)
                end

                def same(ex)
                    @ex && (@ex == ex) && (Time.now < @timeout)
                end
            end

            def mb_from_kb(kb)
                kb /= 1024.0
            end

            class CummulativeData
                def initialize
                    @total_time = 0
                    @idle_time = 0
                end

                def initialize_from_baseline(baseline)
                    total_time = baseline[:total_time]
                    @total_time = total_time unless total_time.nil?
                    i = baseline[:idle]
                    @idle_time = i unless i.nil?
                end

                def get_cpu_time_delta(total_time, idle)
                    total_time_delta = (total_time - @total_time)
                    @total_time = total_time
                    idle_delta = (idle - @idle_time)
                    @idle_time = idle
                    return total_time_delta, idle_delta
                end
            end

            class MetricTuple < Hash
                def self.factory(namespace, name, value, tags = {})
                    result = {}
                    raise ArgumentError, "tags (#{tags.class}) must be a Hash" unless tags.kind_of? Hash
                    tags = Hash.new.merge! tags

                    result[:Origin] = Origin
                    result[:Namespace] = namespace
                    result[:Name] = name
                    result[:Value] = value
                    result[:Tags] = JSON.generate(tags)
                    result[:CollectionTime] = Time.new.utc.strftime("%FT%TZ")
                    result[:Computer] = @@computer if @@computer

                    result
                end

                def self.computer(name)
                    raise ArgumentError, "name must be a string or nil" unless name.nil? || name.kind_of?(String)
                    @@computer = name
                end

                @@computer = nil

                Origin = "vm.azm.ms"
            end # class MetricTuple

        end # class PollingThread

    end # class

end #module
