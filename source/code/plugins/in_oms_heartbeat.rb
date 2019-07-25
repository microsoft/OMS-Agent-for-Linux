#!/usr/local/bin/ruby

module Fluent

  class OMS_Heartbeat_Input < Input
    Plugin.register_input('oms_heartbeat', self)

    def initialize
      super
      require_relative 'heartbeat_lib'
      require_relative 'oms_common'
    end

    config_param :interval, :time, :default => nil
    config_param :tag, :string, :default => "oms.heartbeat"  

    def configure (conf)
      super
    end

    def start
      @heartbeat_lib = HeartbeatModule::Heartbeat.new(HeartbeatModule::RuntimeError.new)

      if @interval
        @finished = false
        @thread = Thread.new(&method(:run_periodic))
      else
        enumerate
      end
    end

    def shutdown
      if @interval
        @finished = true
        @thread.join
      end
    end

    def enumerate
      time = Time.now.to_f
    
      wrapper = @heartbeat_lib.enumerate(time)
      router.emit(@tag, time, wrapper) if wrapper
      @log.info "Sending OMS Heartbeat succeeded at #{OMS::Common.format_time(time)}"
    end

    def run_periodic
      done = @finished
      until done
        sleep(@interval)
        done = @finished
        if !done
          enumerate
        end
      end
    end

  end # OMS_Heartbeat_Input

end # module

