require 'fluent/input'
require 'fluent/config/error'

module Fluent

  class Heartbeat_Request < Input
    Plugin.register_input('heartbeat_request', self)

    def initialize
      super
      require_relative 'agent_maintenance_script'
    end

    config_param :run_interval, :time, :default => '20m'
    config_param :omsadmin_conf_path, :string
    config_param :cert_path, :string
    config_param :key_path, :string
    config_param :pid_path, :string
    config_param :proxy_path, :string, :default => '/etc/opt/microsoft/omsagent/proxy.conf' #optional
    config_param :os_info, :string, :default => '/etc/opt/microsoft/scx/conf/scx-release' #optional
    config_param :install_info, :string, :default => '/etc/opt/microsoft/omsagent/sysconf/installinfo.txt' #optional
    config_param :agentid_path, :string, :default => '/etc/opt/microsoft/omsagent/agentid' #optional

    def configure (conf)
      super
      if !@omsadmin_conf_path
        raise Fluent::ConfigError, "'omsadmin_conf_path' option is required on heartbeat_request input"
      end
      if !@cert_path
        raise Fluent::ConfigError, "'cert_path' option is required on heartbeat_request input"
      end
      if !@key_path
        raise Fluent::ConfigError, "'key_path' option is required on heartbeat_request input"
      end
      if !@pid_path
        raise Fluent::ConfigError, "'pid_path' option is required on heartbeat_request input"
      end
    end

    def start
      @maintenance_script = MaintenanceModule::Maintenance.new(@omsadmin_conf_path, @cert_path,
                              @key_path, @pid_path, @proxy_path, @os_info, @install_info,
                              @agentid_path, @log)

      if @run_interval
        @finished = false
        @condition = ConditionVariable.new
        @mutex = Mutex.new
        @thread = Thread.new(&method(:run_periodic))
      else
        enumerate
      end
    end

    def shutdown
      if @run_interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
      end
    end

    # Any data produced by this is NOT sent to an output plugin or ODS
    def enumerate
      @maintenance_script.heartbeat
    end

    def run_periodic
      @mutex.lock
      done = @finished
      until done
        @condition.wait(@mutex, @run_interval)
        done = @finished
        @mutex.unlock
        if !done
          enumerate
        end
        @mutex.lock
      end
      @mutex.unlock
    end

  end # class Heartbeat_Request

end # module Fluent
