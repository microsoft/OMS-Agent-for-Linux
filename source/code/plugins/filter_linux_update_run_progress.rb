require "rexml/document"
require "cgi"
require 'json'

require_relative 'patch_management_lib'
require_relative 'oms_common'

module Fluent
  class LinuxUpdatesRunProgressFilter < Filter

    Fluent::Plugin.register_filter('filter_linux_update_run_progress', self)

    config_param :current_update_run_file, :string, default: "/var/opt/microsoft/omsagent/state/schedule_run.id"

    def configure(conf)
      super
      @hostname = OMS::Common.get_hostname or "Unknown host"
      # do the usual configuration here   
      @test_conf = conf['test_conf']
    end

    def start
      super
      # This is the first method to be called when it starts running
      # Use it to allocate resources, etc.
      # LinuxUpdates.log = @log
    end

    def shutdown
      super
      # This method is called when Fluentd is shutting down.
      # Use it to free up resources, etc.
    end

    def filter(tag, time, record)
      linuxUpdates = LinuxUpdates.new(@log, @current_update_run_file)
      if tag == "oms.update_progress.yum"
        return linuxUpdates.process_yum_update_run(record, tag, @hostname, time)
      elsif tag == "oms.update_progress.apt"
        return linuxUpdates.process_apt_update_run(record, tag, @hostname, time)
      end
    end # filter
  end # class
end # module
