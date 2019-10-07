# frozen_string_literal: true

require 'test/unit'

module VMInsights

    require_relative 'vminsights_test_mixins.rb'
    require_relative 'vminsights_test_mocklog.rb'

    require_relative File.join(SourcePath, 'VMInsightsEngine.rb')
    require_relative File.join(SourcePath, 'VMInsightsIDataCollector.rb')

    class MetricsEngineConfiguration_test < Test::Unit::TestCase

        include FileUtils

        def setup
            @object_under_test = MetricsEngine::Configuration.new nil, MockLog.new, MockDataCollector.new
        end

        def teardown
            @object_under_test = nil
            @default_config = nil
        end

        DefaultPoll = 60

        def test_configure_default_values
            assert_equal DefaultPoll, @object_under_test.poll_interval
            assert_nil @object_under_test.computer
        end

        def test_config_poll_interval_nil
            assert_raise ArgumentError do @object_under_test.poll_interval = nil; end
            assert_equal DefaultPoll, @object_under_test.poll_interval
        end

        def test_config_poll_interval_not_number
            assert_raise ArgumentError do @object_under_test.poll_interval = "1"; end
            assert_equal DefaultPoll, @object_under_test.poll_interval
        end

        def test_config_poll_interval_negative
            assert_raise ArgumentError do @object_under_test.poll_interval = -1; end
            assert_equal DefaultPoll, @object_under_test.poll_interval
        end

        def test_config_poll_interval_zero
            assert_raise ArgumentError do @object_under_test.poll_interval = 0; end
            assert_equal DefaultPoll, @object_under_test.poll_interval
        end

        def test_config_poll_interval_half
            assert_raise ArgumentError do @object_under_test.poll_interval = 0.5; end
            assert_equal DefaultPoll, @object_under_test.poll_interval
        end

        def test_config_poll_interval_less_than_1
            assert_raise ArgumentError do @object_under_test.poll_interval = 0.9999999999; end
            assert_equal DefaultPoll, @object_under_test.poll_interval
        end

        def test_config_poll_interval_complex
            assert_raise ArgumentError do @object_under_test.poll_interval = 1+0i; end
            assert_equal DefaultPoll, @object_under_test.poll_interval
        end

        def test_config_poll_interval_1
            @object_under_test.poll_interval = 1
            assert_equal 1, @object_under_test.poll_interval
        end


    end # class MetricsEngineConfiguration_test < Test::Unit::TestCase

    class MetricsEngine_test < Test::Unit::TestCase

        require 'json'

        ExpectedOrigin = "vm.azm.ms"

        class ComputerMetric
            Namespace = "Computer"
            Heartbeat = "Heartbeat"
        end

        class Memory
            Namespace = "Memory"
            Available = "AvailableMB"
            Total = "memorySizeMB"
        end

        class Processor
            Namespace = "Processor"
            Utilization = "UtilizationPercentage"
            Total = "totalCpus"
        end

        class LogicalDisk
            Namespace = "LogicalDisk"
            Status = "Status"
            MountPoint = "mountId"
            Free = "FreeSpaceMB"
            Size = "diskSizeMB"
            FreePercent = "FreeSpacePercentage"
            BytesPerSecond = "BytesPerSecond"
            TransfersPerSecond = "TransfersPerSecond"
            ReadBytesPerSecond = "ReadBytesPerSecond"
            ReadsPerSecond = "ReadsPerSecond"
            WriteBytesPerSecond = "WriteBytesPerSecond"
            WritesPerSecond = "WritesPerSecond"
        end

        class Network
            Namespace = "Network"
            Device = "networkDeviceId"
            Read = "ReadBytesPerSecond"
            Write = "WriteBytesPerSecond"
            Bytes = "bytes"
        end

        def setup
            @log = MockLog.new
            @dc = MockDataCollector.new
            @object_under_test = MetricsEngine.new
            @expected_computer = "this.is.the.default.expected.computer.example.com"
            @configuration = MetricsEngine::Configuration.new @expected_computer, @log, @dc

            @sync_point = SyncPoint.new
            @wait_handle = @sync_point.get_wait_handle
        end

        def teardown
            @expected_computer = nil
            @configuration = nil

            @object_under_test.stop rescue nil
            @object_under_test = nil

            @sync_point = nil
            @wait_handle = nil

            @dc = nil

            @log.check
            @log = nil
        end

        def test_ensure_mock_dc_conforms
            assert_kind_of IDataCollector, @dc
            idc = IDataCollector.new.class
            @dc.methods.each { |m|
                refute_equal idc, (@dc.method(m)).owner, "#{@dc.class} doesn't implement #{m}"
            }
        end

        def test_config_passes_computer
            assert_equal @expected_computer, @configuration.computer
        end

        def test_start_nil
            assert_raise ArgumentError do @object_under_test.start nil; end
        end

        def test_start_not_Configuration
            assert_raise ArgumentError do @object_under_test.start Hash[]; end
        end

        def test_start_noproc
            assert_raise ArgumentError do @object_under_test.start @configuration; end
        end

        def test_double_start
            @log.ignore_range = MockLog::INFO_AND_BELOW
            @log.flunk_range = MockLog::WARN_AND_ABOVE
            @object_under_test.start(@configuration) { |m|
                flunk
            }
            assert @object_under_test.running?

            assert_raise RuntimeError do
                @object_under_test.start(@configuration) { |m|
                    flunk
                }
            end

            @object_under_test.stop
        end

        def test_start_stop_start_stop
            @object_under_test.start(@configuration) { |m| }
            assert @object_under_test.running?

            @object_under_test.stop
            assert_false @object_under_test.running?

            @object_under_test.start(@configuration) { |m| }
            assert @object_under_test.running?

            @object_under_test.stop
            assert_false @object_under_test.running?

            assert (4 == @log.size), Proc.new {@log.to_s}
            message_patterns = [ /^Starting polling /, /^Stopping polling$/ ]
            index = 0
            @log.each { |l|
                assert_equal MockLog::INFO, l[:severity], l.to_s
                assert (message_patterns[index].match l[:message]), l.to_s
                index = (index + 1) % message_patterns.size
            }

        end

        def test_stop_no_start
            assert_false @object_under_test.running?
            @object_under_test.stop
            assert_false @object_under_test.running?

        end

        def test_start_double_stop
            @object_under_test.start(@configuration) { |m| }
            assert @object_under_test.running?

            @object_under_test.stop
            assert_false @object_under_test.running?

            @object_under_test.stop
            assert_false @object_under_test.running?

        end

        def test_one_message
            expected_total = 156
            expected_free = 42
            @dc.mock_total_mem_kb = expected_total * 1024
            @dc.mock_free_mem_kb = expected_free * 1024

            expected_cpus = @dc.mock_cpu_count
            expected_cpu_percentage = compute_expected_cpu_use expected_cpus, @dc.mock_cpu_deltas(0)

            polling_interval = 2
            @configuration.poll_interval = polling_interval

            metric_samples = Array.new

            time_before_start = Time.now
            @object_under_test.start(@configuration) { |m|
                metric_samples << m
            }
            assert @object_under_test.running?

            sleep polling_interval * 1.5

            @object_under_test.stop
            assert_false @object_under_test.running?
            time_after_stop = Time.now

            assert_equal 1, metric_samples.length
            assert_equal 1, @dc.sample_intervals.length

            sample, interval = metric_samples[0], @dc.sample_intervals[0]

            assert_operator interval.start_time, :>=, time_before_start + polling_interval
            assert_operator interval.start_time, :<=, time_after_stop

            heartbeat_metric_found = false
            memory_metric_found = false
            processor_metric_found = false
            assert_sample(sample, interval) { |namespace, name, value, tags|
                if (namespace == ComputerMetric::Namespace && name == ComputerMetric::Heartbeat)
                    assert_equal 1, value
                    refute heartbeat_metric_found
                    heartbeat_metric_found = true
                elsif (namespace == Memory::Namespace && name == Memory::Available)
                    assert_equal expected_free, value
                    assert_equal expected_total, tags["#{ExpectedOrigin}/#{Memory::Total}"], tags
                    refute memory_metric_found
                    memory_metric_found = true
                elsif (namespace == Processor::Namespace && name == Processor::Utilization)
                    assert_in_delta expected_cpu_percentage, value, 0.005
                    assert_equal expected_cpus, tags["#{ExpectedOrigin}/#{Processor::Total}"], tags
                    refute processor_metric_found
                    processor_metric_found = true
                else
                    flunk "unexpected metric: Namespace=#{namespace} Name = #{name}"
                end
            }
            assert heartbeat_metric_found
            assert memory_metric_found
            assert processor_metric_found
        end

        def test_null_computer
            @expected_computer = nil
            @configuration = MetricsEngine::Configuration.new @expected_computer, @log, @dc
            test_one_message
        end

        def test_multihome
            @dc.mock_mma_ids = [ "Larry", "Moe", "Curly" ]
            test_one_message
        end

        def test_cpu_use_not_available
            mock_error = IDataCollector::Unavailable.new "mock cpu percent error"
            @dc.get_cpu_use_exception = mock_error

            polling_interval = 1
            @configuration.poll_interval = polling_interval

            metric_samples = Array.new

            time_before_start = Time.now
            @object_under_test.start(@configuration) { |m|
                metric_samples << m
            }
            assert @object_under_test.running?

            sleep polling_interval * 1.5

            @object_under_test.stop
            assert_false @object_under_test.running?
            time_after_stop = Time.now

            assert_equal 1, metric_samples.length
            assert_equal 1, @dc.sample_intervals.length

            sample, interval = metric_samples[0], @dc.sample_intervals[0]

            assert_operator interval.start_time, :>=, time_before_start + polling_interval
            assert_operator interval.start_time, :<=, time_after_stop

            assert_sample(sample, interval) { |namespace, name, value, tags|
                refute (namespace == Processor::Namespace && name == Processor::Utilization)
            }
        end

        def test_cpu_count_not_available
            @log.ignore_range = MockLog::INFO_AND_BELOW
            @log.flunk_range = MockLog::NONE
            expected_exception = IDataCollector::Unavailable.new "this is the error message"
            @dc.get_cpu_count_exception = expected_exception
            polling_interval = 1
            @configuration.poll_interval = polling_interval

            metric_samples = Array.new

            time_before_start = Time.now
            @object_under_test.start(@configuration) { |m|
                metric_samples << m
            }
            assert @object_under_test.running?

            # poll multiple time to check that log only happens once
            sleep polling_interval * 5

            @object_under_test.stop
            assert_false @object_under_test.running?
            time_after_stop = Time.now

            assert_operator 1, :<, @dc.sample_intervals.length
            assert_operator 7, :>=, @dc.sample_intervals.length
            assert_equal @dc.sample_intervals.length, metric_samples.length

            (0 ... @dc.sample_intervals.length).each { |i|
                sample, interval = metric_samples[i], @dc.sample_intervals[i]

                assert_operator interval.start_time, :>=, time_before_start + polling_interval
                assert_operator interval.start_time, :<=, time_after_stop

                assert_sample(sample, interval) { |namespace, name, value, tags|
                    refute (namespace == Processor::Namespace && name == Processor::Utilization)
                }
            }

            msg = Proc.new() {
                @log.to_s
            }
            assert 1 == @log.size, msg
            @log.each { |log|
                    assert_equal MockLog::ERROR, log[:severity]
                    assert_equal expected_exception.to_s, log[:message]
            }
        end

        def test_cpu_uptime_delta_zero
            @dc.mock_cpu_deltas = [
                { :up => 1234567.8, :idle => 54321.0 },
                { :up => 0, :idle => 0 },
            ]

            polling_interval = 1
            @configuration.poll_interval = polling_interval

            metric_samples = Array.new

            time_before_start = Time.now
            @object_under_test.start(@configuration) { |m|
                metric_samples << m
            }
            assert @object_under_test.running?

            sleep polling_interval * 1.5

            @object_under_test.stop
            assert_false @object_under_test.running?
            time_after_stop = Time.now

            assert_equal 1, metric_samples.length
            assert_equal 1, @dc.sample_intervals.length

            sample, interval = metric_samples[0], @dc.sample_intervals[0]

            assert_operator interval.start_time, :>=, time_before_start + polling_interval
            assert_operator interval.start_time, :<=, time_after_stop

            assert_sample(sample, interval) { |namespace, name, value, tags|
                refute (namespace == Processor::Namespace && name == Processor::Utilization)
            }
        end

        def test_memory_not_available
            mock_error = IDataCollector::Unavailable.new "mock memory error"
            @dc.get_available_memory_exception = mock_error

            polling_interval = 1
            @configuration.poll_interval = polling_interval

            metric_samples = Array.new

            time_before_start = Time.now
            @object_under_test.start(@configuration) { |m|
                metric_samples << m
            }
            assert @object_under_test.running?

            sleep polling_interval * 1.5

            @object_under_test.stop
            assert_false @object_under_test.running?
            time_after_stop = Time.now

            assert_equal 1, metric_samples.length
            assert_equal 1, @dc.sample_intervals.length

            sample, interval = metric_samples[0], @dc.sample_intervals[0]

            assert_operator interval.start_time, :>=, time_before_start + polling_interval
            assert_operator interval.start_time, :<=, time_after_stop

            assert_sample(sample, interval) { |namespace, name, value, tags|
                refute (namespace == Memory::Namespace && name == Memory::Available)
            }
        end

        def test_multiple_samples
            expected_total = 156
            expected_free = 42
            increment = 3 # deliberately not a power of 2
            @dc.mock_total_mem_kb = expected_total * 1024
            @dc.mock_free_mem_kb = expected_free * 1024
            @dc.mock_increment_mem_kb = increment

            @dc.mock_cpu_deltas = [
                { :up => 1300, :idle => 100 },
                { :up => 60.01, :idle => 6 },
                { :up => 60.01, :idle => 60 },
                { :up => 60, :idle => 7.5 },
                { :up => 60, :idle => 10 },
                { :up => 60.01, :idle => 12.5 },
                { :up => 60.01, :idle => 50 },
                { :up => 60.01, :idle => 59.9 },
                { :up => 60, :idle => 59.9 },
                { :up => 60, :idle => 0 },
                { :up => 60, :idle => 60 },
                { :up => 60, :idle => 60 },
            ]
            expected_cpus = @dc.mock_cpu_count

            polling_interval = 1
            @configuration.poll_interval = polling_interval

            metric_samples = Array.new

            time_before_start = Time.now
            @object_under_test.start(@configuration) { |m|
                metric_samples << m
            }
            assert @object_under_test.running?

            time_limit = Time.now + (10 * polling_interval)
            while metric_samples.size < 8
                sleep polling_interval * 0.5
                flunk "TIMEOUT" unless Time.now <= time_limit
            end

            @object_under_test.stop
            assert_false @object_under_test.running?
            time_after_stop = Time.now

            assert_operator metric_samples.length, :>=, 8
            assert_equal metric_samples.length, @dc.sample_intervals.length

            heartbeat_metrics_found = 0
            memory_metrics_found = 0
            processor_metrics_found = 0
            expected_time_min = time_before_start
            expected_time_max = expected_time_min + (polling_interval * 2)
            (0...metric_samples.length).each { |i|
                sample, interval = metric_samples[i], @dc.sample_intervals[i]

                assert_operator interval.start_time, :>, expected_time_min, i.to_s
                expected_time_min += polling_interval
                assert_operator interval.start_time, :<, expected_time_max, i.to_s
                expected_time_max += polling_interval

                assert_sample(sample, interval, i) { |namespace, name, value, tags|
                    if (namespace == ComputerMetric::Namespace && name == ComputerMetric::Heartbeat)
                        assert_equal 1, value
                        heartbeat_metrics_found += 1
                    elsif (namespace == Memory::Namespace && name == Memory::Available)
                        assert_in_delta expected_free, value, 1.0/1024.0
                        assert_in_delta expected_total, tags["#{ExpectedOrigin}/#{Memory::Total}"], 1.0/1024.0, tags
                        expected_free += (increment / 1024.0)
                        expected_total += (increment / 1024.0)
                        memory_metrics_found += 1
                    elsif (namespace == Processor::Namespace && name == Processor::Utilization)
                        expected_cpu_percentage = compute_expected_cpu_use expected_cpus, @dc.mock_cpu_deltas(i)
                        assert_in_delta expected_cpu_percentage, value, 0.005
                        assert_equal expected_cpus, tags["#{ExpectedOrigin}/#{Processor::Total}"], tags
                        processor_metrics_found += 1
                    else
                        flunk "unexpected metric: Namespace=#{namespace} Name = #{name}"
                    end
                }
            }

            assert_equal metric_samples.length, heartbeat_metrics_found
            assert_equal metric_samples.length, memory_metrics_found
            assert_equal metric_samples.length, processor_metrics_found
        end

        def test_get_file_system_not_available
            mock_error = IDataCollector::Unavailable.new "mock file system error"
            @dc.get_filesystems_exception = mock_error

            polling_interval = 1
            @configuration.poll_interval = polling_interval

            metric_samples = Array.new

            time_before_start = Time.now
            @object_under_test.start(@configuration) { |m|
                metric_samples << m
            }
            assert @object_under_test.running?

            sleep polling_interval * 1.5

            @object_under_test.stop
            assert_false @object_under_test.running?
            time_after_stop = Time.now

            assert_equal 1, metric_samples.length
            assert_equal 1, @dc.sample_intervals.length

            sample, interval = metric_samples[0], @dc.sample_intervals[0]

            assert_operator interval.start_time, :>=, time_before_start + polling_interval
            assert_operator interval.start_time, :<=, time_after_stop

            assert_sample(sample, interval) { |namespace, name, value, tags|
                refute (namespace == LogicalDisk::Namespace)
            }
        end

        def test_get_file_system
            trunc_size_bytes = ExpectedFs::Mb2b(2) + (ExpectedFs::Mb2b(1) / 2)
            trunc_free_bytes = trunc_size_bytes / 4
            expected_filesystems = [
                ExpectedFs.new(
                    ExpectedFsMount.new(MockFsMount.new("/dev/nil", "/usr/n", trunc_size_bytes, trunc_free_bytes), 2, 0, 25.000),
                    ExpectedFsPerf.new(MockFsPerf.new(nil, nil, nil, nil, 60))
                ),
                ExpectedFs.new(
                    ExpectedFsMount.new(MockFsMount.new("/dev/nil_rwb", "/usr/n_rwb", trunc_size_bytes, trunc_free_bytes), 2, 0, 25.000),
                    ExpectedFsPerf.new(MockFsPerf.new(1 * 60.1, nil, 3 * 60.1, nil, 60))
                ),
                ExpectedFs.new(
                    ExpectedFsMount.new(MockFsMount.new("/dev/d1", "/", ExpectedFs::Gb2b(10), ExpectedFs::Gb2b(1)), ExpectedFs::Gb2Mb(10), ExpectedFs::Gb2Mb(1), 10.000),
                    ExpectedFsPerf.new(MockFsPerf.new(1, 2, 3, 4, 5))
                ),
                # needs to be in the middle to validate that the unavailable performance data doesn't disrupt data for the other disks
                ExpectedFs.new(
                    ExpectedFsMount.new(MockFsMount.new("/dev/unavail", "/usr/un", trunc_size_bytes, trunc_free_bytes), 2, 0, 25.000),
                    ExpectedFsPerf.new(IDataCollector::Unavailable.new("device unavailable"))
                ),
                ExpectedFs.new(
                    ExpectedFsMount.new(MockFsMount.new("/dev/d22", "/usr", ExpectedFs::Gb2b(200), ExpectedFs::Gb2b(35)), ExpectedFs::Gb2Mb(200), ExpectedFs::Gb2Mb(35), 17.500),
                    ExpectedFsPerf.new(MockFsPerf.new(6, 7, 8, 9, 0.5))
                ),
                ExpectedFs.new(
                    ExpectedFsMount.new(MockFsMount.new("/dev/d500", "/usr/trunc", trunc_size_bytes, trunc_free_bytes), 2, 0, 25.000),
                    ExpectedFsPerf.new(MockFsPerf.new(1 * 60.1, 2 * 60.1, 3 * 60.1, 4 * 60.1, 60))
                ),
            ]
            @dc.mock_filesystems = expected_filesystems.map { |f| f.mount.fs }
            @dc.mock_disk_stats = Hash[expected_filesystems.map { |f| [ f.mount.fs.device_name, f.perf.perf ] }]

            polling_interval = 1
            @configuration.poll_interval = polling_interval

            metric_samples = Array.new

            time_before_start = Time.now
            @object_under_test.start(@configuration) { |m|
                metric_samples << m
            }
            assert @object_under_test.running?

            sleep polling_interval * 1.5

            @object_under_test.stop
            assert_false @object_under_test.running?
            time_after_stop = Time.now

            assert_equal 1, metric_samples.length
            assert_equal 1, @dc.sample_intervals.length

            sample, interval = metric_samples[0], @dc.sample_intervals[0]

            assert_operator interval.start_time, :>=, time_before_start + polling_interval
            assert_operator interval.start_time, :<=, time_after_stop

            actual = Hash.new() { |h, k| h[k] = {} }
            assert_sample(sample, interval) { |namespace, name, value, tags|
                if (namespace == LogicalDisk::Namespace)
                    mp = tags["#{ExpectedOrigin}/#{LogicalDisk::MountPoint}"]
                    a = actual[mp]
                    refute a.key?(name), "#{mp}: #{name} duplicated"
                    a[name] = value
                    if (name == LogicalDisk::Free)
                        a[LogicalDisk::Size] = tags["#{ExpectedOrigin}/#{LogicalDisk::Size}"]
                    end
                end
            }

            actual.default_proc = nil
            expected_filesystems.each { |f|
                exp_mt = f.mount
                exp_perf = f.perf
                mp = exp_mt.fs.mount_point
                a = actual.delete(mp)
                refute_nil a, "#{mp}: not in actual"
                label = "#{exp_mt.fs.device_name} mounted on #{mp}"
                begin
                    assert_equal 1, a[LogicalDisk::Status], label
                    assert_equal exp_mt.sizeMb, a[LogicalDisk::Size], label
                    assert_equal exp_mt.freeMb, a[LogicalDisk::Free], label
                    assert_equal exp_mt.freePercent, a[LogicalDisk::FreePercent], label
                    if exp_perf.available?
                        assert_in_delta exp_perf.bytes_per_sec, a[LogicalDisk::BytesPerSecond], 0.000001, label
                        assert_in_delta exp_perf.transfers_per_sec, a[LogicalDisk::TransfersPerSecond], 0.000001, label
                        assert_in_delta exp_perf.read_bytes_per_sec, a[LogicalDisk::ReadBytesPerSecond], 0.000001, label
                        assert_in_delta exp_perf.reads_per_sec, a[LogicalDisk::ReadsPerSecond], 0.000001, label
                        assert_in_delta exp_perf.write_bytes_per_sec, a[LogicalDisk::WriteBytesPerSecond], 0.000001, label
                        assert_in_delta exp_perf.writes_per_sec, a[LogicalDisk::WritesPerSecond], 0.000001, label
                    else
                        refute a.key?(LogicalDisk::BytesPerSecond), label
                        refute a.key?(LogicalDisk::TransfersPerSecond), label
                        refute a.key?(LogicalDisk::ReadBytesPerSecond), label
                        refute a.key?(LogicalDisk::ReadsPerSecond), label
                        refute a.key?(LogicalDisk::WriteBytesPerSecond), label
                        refute a.key?(LogicalDisk::WritesPerSecond), label
                    end
                rescue Test::Unit::AssertionFailedError => afe
                    print "\n#{File.basename(__FILE__)}(#{__LINE__}): #{label}:\n\t#{f.inspect}\n\t#{a.inspect}\n"
                    raise
                end
            }

            assert actual.size == 0, Proc.new() { actual.inspect }

        end

        def test_network
            if0 = "eth0"
            if1 = "tr1"
            polling_interval = 2
            expected = [
                [ ExpectedNet.new(NetData.new(if0, polling_interval.to_f, 2, 4), 1, 2), ExpectedNet.new(NetData.new(if1, polling_interval, 4, 2), 2, 1) ],
                [ ExpectedNet.new(NetData.new(if0, polling_interval, 2469, 4321), 1234.5, 2160.5), ExpectedNet.new(NetData.new(if1, polling_interval, 0, 0), 0, 0) ],
            ]
            @dc.mock_net = expected.map { |e| e.map { |n| n.net } }

            @configuration.poll_interval = polling_interval

            metric_samples = Array.new

            time_before_start = Time.now
            @object_under_test.start(@configuration) { |m|
                metric_samples << m
            }
            assert @object_under_test.running?

            sleep (polling_interval * (expected.size + 0.5))

            @object_under_test.stop
            assert_false @object_under_test.running?
            time_after_stop = Time.now

            assert_equal expected.size, metric_samples.length
            assert_equal expected.size, @dc.sample_intervals.length

            expected_time_range = (time_before_start ... (time_before_start + (polling_interval * 2)))
            (0 ... expected.size).each { |i|
                expect, sample, interval = expected[i], metric_samples[i], @dc.sample_intervals[i]

                assert expected_time_range.cover?(interval.start_time), Proc.new { "#{i}: #{interval.start_time} should be in #{expected_time_range}" }
                expected_time_range = Range.new(expected_time_range.begin + polling_interval,
                                                expected_time_range.end   + polling_interval,
                                                expected_time_range.exclude_end?)

                actual = Hash.new() { |h, k| h[k] = {} }
                assert_sample(sample, interval) { |namespace, name, value, tags|
                    if (namespace == Network::Namespace)
                        dev = tags["#{ExpectedOrigin}/#{Network::Device}"]
                        a = actual[dev]
                        refute a.key?(name), "#{i}: #{dev}: #{name} duplicated"
                        a[name] = value
                        a["#{name}:bytes"] = tags["#{ExpectedOrigin}/#{Network::Bytes}"]
                    end
                }

                actual.default_proc = nil
                expect.each { |n|
                    data = n.net
                    dev = data.device
                    a = actual.delete(dev)
                    refute_nil a, "#{i}: #{dev}: not in actual"

                    begin
                        assert_equal data.bytes_received, a["#{Network::Read}:bytes"]
                        ar = a[Network::Read]
                        assert_in_delta n.rec, ar, 0.0000001

                        assert_equal data.bytes_sent, a["#{Network::Write}:bytes"]
                        aw = a[Network::Write]
                        assert_in_delta n.sent, aw, 0.0000001

                    rescue Test::Unit::AssertionFailedError => afe
                        print "\n#{File.basename(__FILE__)}(#{__LINE__}): #{i}:\n\t#{n.inspect}\n\t#{a}\n"
                        raise
                    end
                }

                assert actual.size == 0, Proc.new() { actual.inspect }

            }

        end

    private

        def assert_sample(sample, sample_interval, label=nil, &block)
            refute_nil sample
            assert_instance_of Array, sample
            refute_equal 0, sample.size

            begin
                @@universal_validators.start_sample
            rescue Test::Unit::AssertionFailedError => afe
                print "\n#{File.basename(__FILE__)}(#{__LINE__}): #{label}: #{sample}\n"
                raise
            end

            start_time_str = sample_interval.start_time.utc.strftime("%FT%TZ")
            stop_time_str = sample_interval.stop_time.utc.strftime("%FT%TZ")

            sample.each_index() { |idx|
                metric = sample[idx]

                begin
                    assert_instance_of Hash, metric

                    assert metric.key?(:Origin)
                    assert_equal ExpectedOrigin, metric[:Origin]

                    assert metric.key?(:CollectionTime)
                    time = metric[:CollectionTime]
                    refute_nil time
                    assert_instance_of String, time
                    assert_operator time, :>=, start_time_str
                    assert_operator time, :<=, stop_time_str

                    assert metric.key?(:Namespace)
                    namespace = metric[:Namespace]
                    refute_nil namespace

                    assert metric.key?(:Name)
                    name = metric[:Name]
                    refute_nil name

                    if @expected_computer.nil?
                        refute metric.key?(:Computer)
                    else
                        assert metric.key?(:Computer)
                        metric[:Computer]
                        assert_equal @expected_computer, metric[:Computer]
                    end

                    assert metric.key?(:Value)
                    value = metric[:Value]
                    refute_nil value
                    assert_kind_of Numeric, value
                    refute_kind_of Complex, value

                    assert metric.key?(:Tags)
                    tags = assert_tags metric[:Tags]

                    @@universal_validators.validate(namespace, name, value, tags)

                    block[namespace, name, value, tags] unless block.nil?
                rescue Test::Unit::AssertionFailedError => afe
                    print "\n#{File.basename(__FILE__)}(#{__LINE__}): #{label}: sample[#{idx}]: '#{metric}'\n"
                    raise
                end
            }

            begin
                @@universal_validators.stop_sample
            rescue Test::Unit::AssertionFailedError => afe
                print "\n#{File.basename(__FILE__)}(#{__LINE__}): #{label}: #{sample}\n"
                raise
            end

        end

        def assert_tags tags
            expected_mma_ids = @dc.mock_mma_ids
            refute_predicate expected_mma_ids, :nil?

            assert_instance_of String, tags
            tags = JSON.parse(tags)
            assert_instance_of Hash, tags

            assert tags.key?("#{ExpectedOrigin}/machineId")
            actual_mma_ids = tags["#{ExpectedOrigin}/machineId"]

            if expected_mma_ids.kind_of? String
                assert_instance_of String, actual_mma_ids
                assert_equal "m-#{expected_mma_ids}", actual_mma_ids
            elsif expected_mma_ids.kind_of? Array
                expected_mma_ids = expected_mma_ids.map { |g| "m-#{g}" }
                assert_instance_of Array, actual_mma_ids
                diff = expected_mma_ids - actual_mma_ids
                assert diff.empty?, "expected #{diff} not in actual"
                diff = actual_mma_ids - expected_mma_ids
                assert diff.empty?, "actual #{diff} not in expected"
            else
                flunk "expected #{expected_mma_ids.class}(#{expected_mma_ids}). #{actual_mma_ids.class}(#{actual_mma_ids}) is wrong type"
            end

            tags
        end

        def compute_expected_cpu_use(cpus, deltas)
            100.0 - (100.0 * deltas[:idle]) / (1.0 * deltas[:up] * cpus)
        end

        class SampleValidator
            include Test::Unit::Assertions

            def initialize(name, metric_validators, &what_to_do_for_unknown_keys)
                @name = name
                @validators = Hash.new
                @validators.default_proc = unless (what_to_do_for_unknown_keys.nil?)
                    what_to_do_for_unknown_keys
                else
                    Proc.new { |hash, key|
                        flunk "#{@name}: unexpected key #{key}"
                    }
                end
                metric_validators.each { |dv| @validators[make_key(dv.namespace, dv.name)] = dv }
            end

            def validate(namespace, name, value, tags)
                @validators[make_key(namespace, name)].validate(value, tags)
            end

            def start_sample
                @validators.each_value { |v| v.start_sample }
            end

            def stop_sample
                @validators.each_value { |v| v.stop_sample }
            end

        private

            def make_key(namespace, name)
                [ namespace, name ]
            end
        end

        class MetricValidator
            include Test::Unit::Assertions

            def initialize(namespace, name)
                @namespace = namespace
                @name = name
            end

            def validate(value, tags)
                # NOP
            end

            def start_sample
                # NOP
            end

            def stop_sample
                # NOP
            end

            def identify
                "#{self.class}: [#{namespace}, #{name}]"
            end

            attr_reader :namespace, :name

        end # class MetricValidator

        class HowManyValidator < MetricValidator

            def initialize(namespace, name, min, max)
                super namespace, name
                @seen = 0
                @min = min
                @max = max
            end

            def validate(value, tags)
                super
                @seen += 1
                assert_operator @seen, :<=, @max, identify
            end

            def start_sample
                super
                @seen = 0
            end

            def stop_sample
                super
                assert_operator @seen, :>=, @min, identify
            end

        end # class HowManyValidator

        class HeartbeatValidator < HowManyValidator

            def initialize
                super ComputerMetric::Namespace, ComputerMetric::Heartbeat, 1, 1
            end

        end # class HeartbeatValidator

        class MemoryValidator < HowManyValidator

            def initialize(name)
                super Memory::Namespace, name, 0, 1
            end

            def validate(value, tags)
                super
                assert_operator value, :>=, 0
            end

        end # class MemoryValidator

        class ProcessorValidator < HowManyValidator

            def initialize(name)
                super Processor::Namespace, name, 0, 1
            end

            def validate(value, tags)
                super
                assert_operator value, :>=, 0.0
                assert_operator value, :<=, 100.0
            end

        end # class ProcessorValidator

        class LogicalDiskValidator < MetricValidator
            def initialize(name)
                super LogicalDisk::Namespace, name
            end

            def validate(value, tags)
                super
                mountId = tags["#{ExpectedOrigin}/#{LogicalDisk::MountPoint}"]
                refute_nil mountId, "mountId tag not found"
                assert mountId.start_with? "/", mountId
            end
        end # class LogicalDiskValidator

        class LogicalDiskStatusValidator < LogicalDiskValidator
            def initialize
                super LogicalDisk::Status
            end

            def validate(value, tags)
                super
                assert_equal 1, value
            end
        end # class LogicalDiskStatusValidator

        class LogicalDiskNonNegativeValueValidator < LogicalDiskValidator
            def initialize(name)
                super
            end

            def validate(value, tags)
                super
                assert_kind_of Numeric, value
                refute_kind_of Complex, value
                assert_operator value, :>=, 0.0
            end
        end # LogicalDiskNonNegativeValueValidator

        class LogicalDiskFreeValidator < LogicalDiskNonNegativeValueValidator
            def initialize
                super LogicalDisk::Free
            end

            def validate(value, tags)
                super

                size = tags["#{ExpectedOrigin}/#{LogicalDisk::Size}"]
                refute_nil size, "disk size tag not found"
                assert_kind_of Numeric, size
                refute_kind_of Complex, size
                assert_operator size, :>, 0.0
            end

        end # class LogicalDiskFreeValidator

        class LogicalDiskFreePercentValidator < LogicalDiskNonNegativeValueValidator
            def initialize
                super LogicalDisk::FreePercent
            end

            def validate(value, tags)
                super

                assert_operator value, :<=, 100.0
            end
        end # class LogicalDiskFreePercentValidator

        class NetworkValidator < MetricValidator

            def initialize(name)
                super Network::Namespace, name
            end

            def validate(value, tags)
                super
                assert_kind_of Numeric, value
                refute_kind_of Complex, value

                assert_operator value, :>=, 0.0

                device = tags["#{ExpectedOrigin}/#{Network::Device}"]
                refute device.nil?, "device id tag not found"
                assert_kind_of String, device
                refute device.empty?

                bytes = tags["#{ExpectedOrigin}/#{Network::Bytes}"]
                refute bytes.nil?, "bytes tag not found"
                assert_kind_of Numeric, bytes
                refute_kind_of Complex, value
                assert_operator bytes, :>=, 0
            end

        end # class NetworkValidator

        class MockFsMount
            # immutable
            def initialize(dev, mount, size, free)
                @device_name = -dev
                @mount_point = -mount
                @size_in_bytes = size
                @free_space_in_bytes = free
            end

            attr_reader :mount_point, :size_in_bytes, :free_space_in_bytes, :device_name
        end

        class ExpectedFsMount
            def initialize(mockFSMount, sizeMb, freeMb, freePercent)
                @fs = mockFSMount
                @sizeMb = sizeMb
                @freeMb = freeMb
                @freePercent = freePercent
            end

            attr_reader :fs, :sizeMb, :freeMb, :freePercent

        end

        class MockFsPerf
            def initialize(r, rb, w, wb, dt)
                @reads = r
                @bytes_read = rb
                @writes = w
                @bytes_written = wb
                @delta_time = dt
            end

            attr_reader :reads, :bytes_read, :writes, :bytes_written, :delta_time
        end

        class ExpectedFsPerf
            def initialize(mockPerf)
                @perf = mockPerf
            end

            attr_reader :perf

            def available?
                not(@perf.kind_of? Exception)
            end

            def bytes_per_sec
                r = read_bytes_per_sec
                w = write_bytes_per_sec
                (r.nil? || w.nil?) ? nil : (r + w)
            end

            def transfers_per_sec
                r = reads_per_sec
                w = writes_per_sec
                (r.nil? || w.nil?) ? nil : (r + w)
            end

            def read_bytes_per_sec
                v = @perf.bytes_read
                v.nil? ? nil : (v.to_f / @perf.delta_time.to_f)
            end

            def reads_per_sec
                v = @perf.reads
                v.nil? ? nil : (v.to_f / @perf.delta_time.to_f)
            end

            def write_bytes_per_sec
                v = @perf.bytes_written
                v.nil? ? nil : (v.to_f / @perf.delta_time.to_f)
            end

            def writes_per_sec
                v = @perf.writes
                v.nil? ? nil : (v.to_f / @perf.delta_time.to_f)
            end
        end

        class ExpectedFs
            def initialize(mount, perf)
                @mount = mount
                @perf = perf
            end

            attr_reader :mount, :perf

            def self.Kb2b(kb)
                (kb * 1024)
            end

            def self.Mb2b(mb)
                Kb2b(mb * 1024)
            end

            def self.Gb2Mb(gb)
                gb * 1024
            end

            def self.Gb2b(gb)
                Mb2b(gb * 1024)
            end
        end

        class NetData
            def initialize(d, dt, r, s)
                @device = d
                @delta_time = dt
                @bytes_received = r
                @bytes_sent = s
            end

            attr_reader :device, :delta_time, :bytes_received, :bytes_sent
        end

        class ExpectedNet
            def initialize(net, r, s)
                @net = net
                @rec = r
                @sent = s
            end

            attr_reader :net, :rec, :sent
        end

        @@universal_validators = SampleValidator.new "Universal Validation", [
                                                                        HeartbeatValidator.new,
                                                                        MemoryValidator.new(Memory::Available),
                                                                        ProcessorValidator.new(Processor::Utilization),
                                                                        LogicalDiskStatusValidator.new,
                                                                        LogicalDiskFreeValidator.new,
                                                                        LogicalDiskFreePercentValidator.new,
                                                                        LogicalDiskNonNegativeValueValidator.new(LogicalDisk::ReadsPerSecond),
                                                                        LogicalDiskNonNegativeValueValidator.new(LogicalDisk::WritesPerSecond),
                                                                        LogicalDiskNonNegativeValueValidator.new(LogicalDisk::TransfersPerSecond),
                                                                        LogicalDiskNonNegativeValueValidator.new(LogicalDisk::ReadBytesPerSecond),
                                                                        LogicalDiskNonNegativeValueValidator.new(LogicalDisk::WriteBytesPerSecond),
                                                                        LogicalDiskNonNegativeValueValidator.new(LogicalDisk::BytesPerSecond),
                                                                        NetworkValidator.new(Network::Read),
                                                                        NetworkValidator.new(Network::Write),
                                                                ]

    end # class


    class MockDataCollector < IDataCollector
        def initialize
            @mock_free_mem_kb = 42 * 1024
            @mock_total_mem_kb = 42 * 1024
            @mock_increment_mem_kb = 0
            @get_available_memory_exception = nil

            @mock_cpu_uptime = 0
            @mock_cpu_idle = 0
            @mock_cpu_baseline =
                            { :up => 42, :idle => 17 }
            @mock_cpu_deltas = [
                            { :up => 3, :idle => 0.5 },
                            { :up => 3, :idle => 0.5 },
                            { :up => 3, :idle => 0.5 },
                            { :up => 3, :idle => 0.5 },
                            { :up => 3, :idle => 0.5 },
                            { :up => 3, :idle => 0.5 },
                            { :up => 3, :idle => 0.5 },
                            { :up => 3, :idle => 0.5 },
            ]
            @mock_index = 0
            @mock_cpu_count = 6
            @get_cpu_use_exception = nil
            @get_cpu_count_exception = nil

            @get_filesystems_exception = nil
            @mock_filesystems = []

            @get_disk_stats_exception = nil
            @mock_disk_stats = { }

            @mock_net = []

            @mock_mma_ids = "deadbeef-abcd-efgh-ijkl-1234567890123456"

            @baselined = false

            @sample_intervals = []
            @current_interval = nil
        end

        def baseline
            @baselined = true
            @mock_cpu_uptime += @mock_cpu_baseline[:up]
            @mock_cpu_idle += @mock_cpu_baseline[:idle]
            @mock_cpu_baseline
        end

        def start_sample
            raise RuntimeError, "baseline not called" unless @baselined
            raise RuntimeError, "sampling in progress" unless @current_interval.nil?
            @current_interval = SampleInterval.new
        end

        def end_sample
            raise RuntimeError, "not sampling" if @current_interval.nil?
            @current_interval.stop
            @sample_intervals << @current_interval
            @current_interval = nil
        end

        def get_available_memory_kb
            raise @get_available_memory_exception if @get_available_memory_exception
            result = [ @mock_free_mem_kb, @mock_total_mem_kb ]
            @mock_free_mem_kb += @mock_increment_mem_kb
            @mock_total_mem_kb += @mock_increment_mem_kb
            return result
        end

        def get_cpu_idle
            raise @get_cpu_use_exception unless @get_cpu_use_exception.nil?
            result = @mock_cpu_deltas[@mock_index % @mock_cpu_deltas.size]
            @mock_index += 1
            @mock_cpu_uptime += result[:up]
            @mock_cpu_idle += result[:idle]
            return @mock_cpu_uptime, @mock_cpu_idle
        end

        def get_number_of_cpus
            raise @get_cpu_count_exception unless @get_cpu_count_exception.nil?
            @mock_cpu_count
        end

        def get_mma_ids
            @mock_mma_ids
        end

        def get_filesystems
            raise @get_filesystems_exception unless @get_filesystems_exception.nil?
            @mock_filesystems
        end

        def mock_cpu_deltas(i)
            @mock_cpu_deltas[i % @mock_cpu_deltas.size].clone
        end

        def mock_cpu_deltas=(a)
            @mock_cpu_baseline = a.shift
            @mock_cpu_deltas = a
        end

        def mock_net=(d)
            @mock_net = Array.new(d)
        end

        # returns:
        #   An array of objects with methods:
        #       device
        #       bytes_received  since last call or baseline
        #       bytes_sent      since last call or baseline
        #       delta_time      time, in seconds, since last sample
        #   Note: Only devices that are "UP" or had activity are included
        def get_net_stats
            return [] if @mock_net.empty?
            @mock_net.shift
        end

        def get_disk_stats(dev)
            raise RuntimeError, "dev is nil" if dev.nil?
            raise RuntimeError, "#{dev} does not start with /dev" unless dev.start_with?("/dev/")
            raise @get_disk_stats_exception unless @get_disk_stats_exception.nil?
            data = @mock_disk_stats[dev]
            raise RuntimeError, dev if data.nil?
            raise data if data.kind_of?(Exception)
            data
        end

        attr_writer :mock_free_mem_kb, :mock_total_mem_kb, :get_available_memory_exception, :mock_increment_mem_kb
        attr_writer :get_cpu_use_exception, :get_cpu_count_exception
        attr_writer :get_filesystems_exception, :mock_filesystems
        attr_writer :get_disk_stats_exception, :mock_disk_stats
        attr_accessor :mock_mma_ids
        attr_reader :sample_intervals, :mock_cpu_count

    private

        class SampleInterval
            def initialize
                @start_time = Time.now
                @stop_time = nil
            end
            def stop
                @stop_time = Time.now
            end

            attr_reader :start_time, :stop_time

        end # class SampleInterval

    end # class MockDataCollector

end #module
