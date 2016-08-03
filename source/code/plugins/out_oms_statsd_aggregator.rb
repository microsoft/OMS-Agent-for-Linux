module Fluent

  class OutputOMSStatsdAggregator < Output

    Plugin.register_output('statsd_aggregator', self)

    def initialize
      super
      require_relative 'statsd_lib'
      require_relative 'omslog'
      require_relative 'oms_configuration'
      require_relative 'oms_common'
    end

    config_param :flush_interval, :time, :default => 10
    config_param :threshold_percentile, :integer, :default => 90
    config_param :persist_file, :string, :default => '/var/opt/microsoft/omsagent/state/statsd.data'
    config_param :out_tag, :string

    def configure(conf)
      super
      @statsd = OMS::StatsDState.new(@flush_interval, @threshold_percentile, @persist_file, @log)
    end

    def start
      super

      @finished = false
      @condition = ConditionVariable.new
      @mutex = Mutex.new
      @thread = Thread.new(&method(:run_periodic))
    end

    def shutdown
      super

      @mutex.synchronize {
        @finished = true
        @condition.signal
      }
      @thread.join
    end

    def emit(tag, es, chain)
      chain.next
      es.each {| time, record |
        @log.debug "Receiving data in aggregator #{time}, #{record}"
        @statsd.receive(record['message'])
      }
    end

  private

    def enumerate
      time = Time.now.to_f

      wrapper = {
        "DataType" => "LINUX_PERF_BLOB",
        "IPName" => "LogManagement",
        "DataItems" => @statsd.convert_to_oms_format(time, OMS::Common.get_hostname)
      }

      Fluent::Engine.emit(@out_tag, time, wrapper)
    end

    def run_periodic
      @mutex.lock
      done = @finished
      until done
        @condition.wait(@mutex, @flush_interval)
        done = @finished
        @mutex.unlock
        if !done
          enumerate
        end
        @mutex.lock
      end
      @mutex.unlock
    end

  end # class

end # module Fluent
