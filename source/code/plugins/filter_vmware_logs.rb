module Fluent
  class VmwareSyslogFilter < Filter

    Fluent::Plugin.register_filter('filter_vmware_logs', self)

    def initialize
      super
      require 'json'
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
      data = Hash[ [:TimeGenerated, :EventTime, :HostName, :HostIP, :SyslogFacility, :SyslogSeverity, :ProcessName, :SyslogMessage].zip(record['message'].split(' : ',8)) ]

      # Co-relation fields
      data[:Computer] = 'ip-' + data[:HostIP].to_s.split('.').join('-')
      data[:ResourceName] = 'VMWare'
      data[:ResourceLocation] = 'VMWare'
      data[:ResourceType] = 'Hypervisor'
      data[:ResourceId] = data[:HostName]

      begin
        data[:Device] = data[:SyslogMessage].to_s.match(/naa\.[a-z0-9]{32}/).to_s
        data[:SCSIStatus] = data[:SyslogMessage].to_s.match(/\sH:[a-z0-9]{1,2}x[a-z0-9]{1,2}\sD:[a-z0-9]{1,2}x[a-z0-9]{1,2}\sP:[a-z0-9]{1,2}x[a-z0-9]{1,2}\s/).to_s
        if data[:ProcessName] == 'vobd'
          failure = data[:SyslogMessage].to_s.scan(/\[([^\]]*)\]/).flatten[1]
          if failure.include?('esx.problem')
            data[:ESXIFailure] = failure
          end
        end

        if ['latency', 'average value', 'microseconds'].all? { |s| data[:SyslogMessage].include? s }
          data[:StorageLatency] = data[:SyslogMessage].match(/to\s[0-9]{5}\smicroseconds/).to_s.split(' ')[1]
        end
      rescue Exception => e
        OMS::Log.error_once("Unable to parse fields: #{e.message}")
      end

      data.delete :TimeGenerated
      data.delete :SyslogFacility
      data.delete :SyslogSeverity

      data
    end
  end
end