require "rexml/document"
require "cgi"

require_relative 'oms_common'

module Fluent
  class ChangeTrackingFilter < Filter

    Fluent::Plugin.register_filter('filter_changetracking', self)

    # config_param works like other plugins

    def configure(conf)
      super
      @hostname = OMS::Common.get_hostname or "Unknown host"
      # do the usual configuration here
    end

    def start
      super
      # This is the first method to be called when it starts running
      # Use it to allocate resources, etc.
    end

    def shutdown
      super
      # This method is called when Fluentd is shutting down.
      # Use it to free up resources, etc.
    end

    def filter(tag, time, record)
        
      
      xml_string = record['xml']
      xml_unescaped_string = CGI::unescapeHTML(xml_string)
      @log.trace "Filtering xml" # #{xml_unescaped_string}"
      xml = REXML::Document.new xml_string
      
      #formatter = REXML::Formatters::Pretty.new(2)
      #formatter.compact = true
      #formatter.write(xml, $stdout)
      
      out_schema = {
        "DataType" => "CONFIG_CHANGE_BLOB",
        "IPName" => "changetracking",
        "DataItems" => [
                        {
                          "Timestamp" => OMS::Common.format_time(time),
                          "Computer" => @hostname,
                          "ConfigChangeType" => "Daemons",
                          "Collections" => [
                                            {
                                              "CollectionName": "iprdump",
                                              "Name": "iprdump",
                                              "Description": "iprdump description goes here",
                                              "State": "Stopped",
                                              "Path": "/etc/rc.d/init.d/iprdump",
                                              "Runlevels": "2, 3, 4, 5",
                                              "Enabled": "false",
                                              "Controller": "iprdump controller value"
                                            },
                                            {
                                              "CollectionName": "network",
                                              "Name": "network",
                                              "Description": "networking networky things",
                                              "State": "Running",
                                              "Path": "/path/where/network/lives",
                                              "Runlevels": "2, 3, 4, 5",
                                              "Enabled": "true",
                                              "Controller": "network controller value"
                                            }

                                           ]
                        }
                       ]
      }

      #record
      out_schema

    end # filter

  end # class
end # module
