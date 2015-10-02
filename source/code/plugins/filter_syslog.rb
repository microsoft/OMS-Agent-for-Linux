module Fluent
  class SyslogFilter < Filter

    Fluent::Plugin.register_filter('filter_syslog', self)

    def initialize
        super
        require 'socket'
        require 'time'
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
      record["Timestamp"] = Time.at(time).utc.iso8601

      record["Host"] = record["host"]
      record.delete "host"

      begin
        addrinfos = Socket::getaddrinfo(Socket.gethostname, "echo", Socket::AF_UNSPEC)
      rescue => e
        $log.error "Failed to call getaddrinfo : #{e}"
        record["HostIP"] = "Unknown IP"
      else
        record["HostIP"] = addrinfos.size >= 1 ? addrinfos[0][3] : "Unknown IP"
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
