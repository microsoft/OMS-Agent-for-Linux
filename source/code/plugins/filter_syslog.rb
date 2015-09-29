module Fluent
  class SyslogFilter < Filter

    Fluent::Plugin.register_filter('filter_syslog', self)

    SEVERITY_MAP = {
        'emerg'  => 0,
        'alert'  => 1,
        'crit'  => 2,
        'err'  => 3,
        'warn'  => 4,
        'notice'  => 5,
        'info'  => 6,
        'debug'  => 7
    }

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
      # The tag looks like this : oms.syslog.authpriv.notice
      tags = tag.split('.')
      record["Timestamp"] = Time.now.strftime("%Y-%m-%dT%H:%M:%S")
      record["Facility"] = tags[2]
      record["Severity"] = SEVERITY_MAP[tags[3]]
      wrapper = {
        "DataType"=>"LINUX_SYSLOGS_BLOB",
        "IPName"=>"logmanagement",
        "DataItems"=>[record]
      }

      # $log.info "SyslogFilter: #{tag} #{wrapper}"
      wrapper
    end
  end
end
