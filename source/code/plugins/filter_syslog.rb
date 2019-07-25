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
    # TODO: fix after dsc removal: use fast_utc_to_iso8601_format from OMS_COMMON.rb
    def fast_utc_to_iso8601_format(utctime, fraction_digits=3)
      utctime.strftime("%FT%T.%#{fraction_digits}NZ")
    end

    def filter(tag, time, record)
      pid = record["pid"]
      hostname = record["host"]
      tags = tag.split('.') # The tag should looks like this : oms.syslog.authpriv.notice
      new_record = {
          'indent' => record['ident'],
          # Use Time.now, because it is the only way to get subsecond precision in version 0.12.
          # The time may be slightly in the future from the ingestion time.
          'Timestamp' => fast_utc_to_iso8601_format(Time.now.utc),
          'EventTime' => fast_utc_to_iso8601_format(Time.at(time).utc),
          'Host' => hostname,
          'HostIP' => 'Unknown IP',
          'Message' => record['message']
      }

      new_record["ProcessId"] = pid if pid

      host_ip = @ip_cache.get_ip(hostname)
      if host_ip.nil?
        OMS::Log.warn_once("Failed to get the IP for #{hostname}.")
      else
        new_record["HostIP"] = host_ip
      end

      if tags.size == 4
        new_record["Facility"] = tags[2]
        new_record["Severity"] = tags[3]
      else
        $log.error "The syslog tag does not have 4 parts #{tag}"
      end

      wrapper = {
        "DataType"=>"LINUX_SYSLOGS_BLOB",
        "IPName"=>"LOGMANAGEMENT",
        "DataItems"=>[new_record]
      }

      wrapper
    end
  end
end
