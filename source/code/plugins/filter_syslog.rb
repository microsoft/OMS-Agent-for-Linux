module Fluent
  class SyslogFilter < Filter

    Fluent::Plugin.register_filter('filter_syslog', self)

    def initialize
      super
      require 'socket'
      require_relative 'omslog'
      require_relative 'oms_common'
    end

    # Interval in seconds to refresh the cache
    config_param :ip_cache_refresh_interval, :integer, :default => 300

    def configure(conf)
      super
      @ip_cache = OMS::IPcache.new @ip_cache_refresh_interval
    end

    def start
      super
    end

    def shutdown
      super
    end

    def filter(tag, time, record)
      # Use Time.now, because it is the only way to get subsecond precision in version 0.12.
      # The time may be slightly in the future from the ingestion time.
      record["Timestamp"] = OMS::Common.format_time(Time.now.to_f)
      record["EventTime"] = OMS::Common.format_time(time)
      hostname = record["host"]
      record["Host"] = hostname
      record.delete "host"
      record["HostIP"] = "Unknown IP"

      host_ip = @ip_cache.get_ip(hostname)
      if host_ip.nil?
          OMS::Log.warn_once("Failed to get the IP for #{hostname}.")
      else
        record["HostIP"] = host_ip
      end

      if record.has_key?("pid")
        record["ProcessId"] = record["pid"]
        record.delete "pid"
      end

      # The tag should looks like this : oms.syslog.authpriv.notice
      tags = tag.split('.')
      if tags.size == 4
        record["Facility"] = tags[2]
        record["Severity"] = tags[3]
      else
        $log.error "The syslog tag does not have 4 parts #{tag}"
      end

      record["Message"] = record["message"]
      record.delete "message"

      wrapper = {
        "DataType"=>"LINUX_SYSLOGS_BLOB",
        "IPName"=>"logmanagement",
        "DataItems"=>[record]
      }

      wrapper
    end
  end
end
