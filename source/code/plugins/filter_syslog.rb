module Fluent
  class SyslogFilter < Filter

    Fluent::Plugin.register_filter('filter_syslog', self)

    def initialize
      super
      require 'socket'
      require_relative 'omslog'
      require_relative 'oms_common'
    end

    def configure(conf)
      super
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
      record["Host"] = record["host"]
      record.delete "host"
      record["HostIP"] = "Unknown IP"

      hostname = OMS::Common.get_hostname
      if hostname == nil
          OMS::Log.warn_once("Failed to get the hostname. Won't be able to get the HostIP.")
      else
        begin
          addrinfos = Socket::getaddrinfo(hostname, "echo", Socket::AF_UNSPEC)
        rescue => e
          OMS::Log.warn_once("Failed to call getaddrinfo : #{e}")
        else
          if addrinfos.size >= 1
            record["HostIP"] = addrinfos[0][3]
          end
        end
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
