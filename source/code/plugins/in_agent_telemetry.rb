require 'fluent/input'
require 'fluent/config/error'

module Fluent

  class Agent_Telemetry < Input
    Plugin.register_input('agent_telemetry', self)

    def initialize
      super
      require_relative 'agent_telemetry_script'
      require_relative 'oms_configuration'
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
      if defined?(OMS::Configuration.telemetry_interval) # ensure new modules are in place, otherwise do not start
        @telemetry_script = OMS::Telemetry.new(@omsadmin_conf_path, @cert_path, @key_path, @pid_path,
                                              @proxy_path, @os_info, @install_info, @log)

        if @query_interval and @poll_interval
          @finished = false
          @thread = Thread.new(&method(:run_periodic))
        end
      end
    end

    def shutdown
      if defined?(OMS::Configuration.telemetry_interval)
        @finished = true
        @thread.join
      end
      super
    end

    def run_periodic
      next_heartbeat = Time.now + @query_interval
      until @finished
        now = Time.now
        if now > next_heartbeat
          @telemetry_script.heartbeat
          query_interval = OMS::Configuration.telemetry_interval
          @query_interval = query_interval if !query_interval.nil? and query_interval.between?(MIN_QUERY_INTERVAL, MAX_QUERY_INTERVAL)
          next_heartbeat = now + @query_interval
        end
        @telemetry_script.poll_resource_usage
        sleep @poll_interval
      end
    end

  end # class Agent_Telemetry

end # module Fluent
