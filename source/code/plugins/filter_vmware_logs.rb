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
      data[:ResourceName] = 'VMware'
      data[:ResourceLocation] = 'VMware'
      data[:ResourceType] = 'Hypervisor'
      data[:ResourceId] = data[:HostName]

      begin
        # Regex for Device. Example string: naa.60a9800041764b6c463f43786855a3t2
        data[:Device] = data[:SyslogMessage].to_s.match(/naa\.[a-z0-9]{32}/).to_s
        # Regex for SCSI Status. Example string: H:0x8 D:0x0 P:0x0 
        data[:SCSIStatus] = data[:SyslogMessage].to_s.match(/\sH\:[a-z0-9]{1,2}x[a-z0-9]{1,2}\sD\:[a-z0-9]{1,2}x[a-z0-9]{1,2}\sP\:[a-z0-9]{1,2}x[a-z0-9]{1,2}\s/).to_s.strip
        if data[:ProcessName] == 'vobd'
          # Regex for ESXI Failure. Example string: [esx.problem.scsi.device.io.latency.high]
          failure = data[:SyslogMessage].to_s.scan(/\[([^\]]*)\]/).flatten[1]
          if failure.include?('esx.problem')
            data[:ESXIFailure] = failure.gsub('esx.problem.', '')
          end
        end

        # Regex for Storage Latency. Example string: I/O latency increased from average value of 1343 microseconds to 28022 microseconds.
        if ['latency', 'average value', 'microseconds'].all? { |s| data[:SyslogMessage].include? s }
          data[:StorageLatency] = data[:SyslogMessage].match(/to\s[0-9]{5}\smicroseconds/).to_s.split(' ')[1]
        end
      rescue Exception => e
        OMS::Log.error_once("Unable to parse VMware ESXI log fields: #{e.message}")
      end

      data.delete :TimeGenerated
      data.delete :SyslogFacility
      data.delete :SyslogSeverity
      data.delete :Device if data[:Device].empty?
      data.delete :SCSIStatus if data[:SCSIStatus].empty?

      data
    end
  end
end