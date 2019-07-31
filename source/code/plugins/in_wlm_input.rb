#!/usr/local/bin/ruby

module Fluent

  class WlmInput < Input
    Plugin.register_input('wlm_input', self)

    def initialize
      super
      require_relative 'wlm_source_lib'
    end

    config_param :source #required
    config_param :interval, :time, :default => nil
    config_param :tag, :string, :default => "oms.wlm.ad"  
    config_param :config_path, :string, :default => "/etc/opt/microsoft/omsagent/conf/omsagent.d/wlm_ad_pe_config.json"
    config_param :data_type, :string, :default => "WLM_AUTO_DISCOVER"
    config_param :ip, :string, :default => "INFRASTRUCTURE_INSIGHTS"

    def configure (conf)
      super
    end

    def start
      # The WlmSourceLib is a factory that selects the appropriate source from the config file
      begin 
        @wlm_source_lib = WLM::WlmSourceLib.new(@source, @config_path)
        if @interval
          @finished = false
          @condition = ConditionVariable.new
          @mutex = Mutex.new
          @thread = Thread.new(&method(:run_periodic))
        else
          get_emit_data
        end #if

      rescue => e
        $log.error "Error while configuring the data source. #{e}."
      end #begin

    end #start 

    def shutdown
      if @interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
      end
    end #shutdown

    def get_emit_data
      wrapper = nil
      time = Time.now.to_s
      begin
        wrapper = @wlm_source_lib.get_data(time, @data_type, @ip)
      rescue => e
        $log.error "Error while executing get_data. #{e}" 
      end 
      router.emit(@tag, time, wrapper) if wrapper
    end #get_emit_data

    def run_periodic
      @mutex.lock
      done = @finished
      until done
        @condition.wait(@mutex, @interval)
        done = @finished
        @mutex.unlock
        if !done
          get_emit_data
        end
        @mutex.lock
      end
      @mutex.unlock
    end #run_periodic

  end #WlmAutoDiscoverInput 

end # module
