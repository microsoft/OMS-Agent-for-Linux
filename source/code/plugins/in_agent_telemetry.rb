require 'fluent/input'
require 'fluent/config/error'

module Fluent

  class Agent_Telemetry < Input
    Plugin.register_input('agent_telemetry', self)

    def initialize
      super
      require_relative 'agent_telemetry_script'
      require_relative 'oms_configuration'
      require_relative 'omslog'
    end

    config_param :query_interval, :time, :default => '5m'
    config_param :poll_interval, :time, :default => '15s'
    config_param :omsadmin_conf_path, :string
    config_param :cert_path, :string
    config_param :key_path, :string
    config_param :pid_path, :string
    config_param :proxy_path, :string, :default => '/etc/opt/microsoft/omsagent/proxy.conf' #optional
    config_param :os_info, :string, :default => '/etc/opt/microsoft/scx/conf/scx-release' #optional
    config_param :install_info, :string, :default => '/etc/opt/microsoft/omsagent/sysconf/installinfo.txt' #optional

    MIN_QUERY_INTERVAL = 1
    MAX_QUERY_INTERVAL = 60 * 60 * 1

    def configure (conf)
      super
      if !@omsadmin_conf_path
        raise Fluent::ConfigError, "'omsadmin_conf_path' option is required on agent_telemetry input"
      end
      if !@cert_path
        raise Fluent::ConfigError, "'cert_path' option is required on agent_telemetry input"
      end
      if !@key_path
        raise Fluent::ConfigError, "'key_path' option is required on agent_telemetry input"
      end
      if !@pid_path
        raise Fluent::ConfigError, "'pid_path' option is required on agent_telemetry input"
      end
    end

    def start
      super
      @telemetry_script = OMS::Telemetry.new(@omsadmin_conf_path, @cert_path, @key_path, @pid_path,
                                             @proxy_path, @os_info, @install_info, @log, false)

      if @query_interval and @poll_interval
        @finished = false
        @thread = Thread.new(&method(:run_periodic))
      end
    end

    def shutdown 
      @finished = true 
      @thread.join
      super
    end

    def run_periodic
      next_heartbeat = Time.now + @query_interval
      until @finished
        now = Time.now
        if now > next_heartbeat
            @telemetry_script.heartbeat
            query_interval = OMS::Configuration.telemetry_interval
            @query_interval = query_interval if query_interval.between?(MIN_QUERY_INTERVAL, MAX_QUERY_INTERVAL)
            next_heartbeat = now + @query_interval
        end
        @telemetry_script.poll_resource_usage
        sleep @poll_interval
    end

    # def start
    #   @telemetry_script = OMS::Telemetry.new(@omsadmin_conf_path, @cert_path, @key_path,
    #                                          @pid_path, @proxy_path, @os_info, @install_info, @log, false)

    #   if @query_interval and @poll_interval
    #     @query_finished = false
    #     @poll_finished = false
    #     @query_condition = ConditionVariable.new
    #     @poll_condition = ConditionVariable.new
    #     @query_mutex = Mutex.new
    #     @poll_mutex = Mutex.new
    #     @query_thread = Thread.new(&method(:query_periodic))
    #     @poll_thread = Thread.new(&method(:poll_periodic))
    #   end
    # end

    # def shutdown
    #   if @query_interval and @poll_interval
    #     @poll_mutex.synchronize {
    #       @poll_finished = true
    #       @poll_condition.signal
    #     }
    #     @poll_thread.join

    #     @query_mutex.synchronize {
    #       @query_finished = true
    #       @query_condition.signal
    #     }
    #     @query_thread.join
    #   end
    # end

    # def poll
    #   @telemetry_script.poll_resource_usage
    # end
    
    # def query
    #   @telemetry_script.heartbeat
    #   query_interval = OMS::Configuration.telemetry_interval
    #   @query_interval = query_interval if query_interval.between?(MIN_QUERY_INTERVAL, MAX_QUERY_INTERVAL)
    # end

    # def poll_periodic
    #   @poll_mutex.lock
    #   done = @poll_finished
    #   until done
    #     @poll_condition.wait(@query_mutex, @query_interval)
    #     done = @query_finished
    #     @query_mutex.unlock
    #     if !done
    #       poll
    #     end
    #     @query_mutex.lock
    #   end
    #   @query_mutex.unlock
    # end

    # def query_periodic
    #   @query_mutex.lock
    #   done = @query_finished
    #   until done
    #     @query_condition.wait(@query_mutex, @query_interval)
    #     done = @query_finished
    #     @query_mutex.unlock
    #     if !done
    #       query
    #     end
    #     @query_mutex.lock
    #   end
    #   @query_mutex.unlock
    # end

  end # class Agent_Telemetry

end # module Fluent
