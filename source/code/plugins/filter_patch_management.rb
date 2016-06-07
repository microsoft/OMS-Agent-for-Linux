require "rexml/document"
require "cgi"

require_relative 'lib_patch_management'
require_relative 'oms_common'

module Fluent
  class LinuxUpdatesFilter < Filter

    Fluent::Plugin.register_filter('filter_patch_management', self)

    # config_param works like other plugins
    # Force sending the change tracking data even if it is identical to the previous snapshot
    config_param :force_send_run_interval, :time, default: 0

    def configure(conf)
      super
      @hostname = OMS::Common.get_hostname or "Unknown host"
      # do the usual configuration here
    end

    def start
      super
      # This is the first method to be called when it starts running
      # Use it to allocate resources, etc.
      LinuxUpdates.log = @log
    end

    def shutdown
      super
      # This method is called when Fluentd is shutting down.
      # Use it to free up resources, etc.
    end

    def filter(tag, time, record)
      xml_string = record['xml']
      @log.debug "LinuxUpdates : Filtering xml size=#{xml_string.size}"
      return LinuxUpdates.transform_and_wrap(xml_string, @hostname, time, @force_send_run_interval)
    end # filter

  end # class
end # module
