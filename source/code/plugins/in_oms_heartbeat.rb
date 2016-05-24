#!/usr/local/bin/ruby

module Fluent

  class OMS_Heartbeat_Input < Input
    Plugin.register_input('oms_heartbeat', self)

    def initialize
      super
      require_relative 'heartbeat_lib'
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
        @condition = ConditionVariable.new
        @mutex = Mutex.new
        @thread = Thread.new(&method(:run_periodic))
      else
        enumerate
      end
    end

    def shutdown
      if @interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
      end
    end

    def enumerate
      time = Time.now.to_f
    
      wrapper = @heartbeat_lib.enumerate(time)
      router.emit(@tag, time, wrapper) if wrapper
    end

    def run_periodic
      @mutex.lock
      done = @finished
      until done
        @condition.wait(@mutex, @interval)
        done = @finished
        @mutex.unlock
        if !done
          enumerate
        end
        @mutex.lock
      end
      @mutex.unlock
    end

  end # OMS_Heartbeat_Input

end # module

