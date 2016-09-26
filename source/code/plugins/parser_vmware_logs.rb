module Fluent
  class TextParser
    class VMwareSyslogParser < Parser
      Plugin.register_parser("parse_vmware_logs", self)

      REGEX = /^(?<EventTime>\S+)\s{0,4}(?<HostName>\S+)\s{0,4}(?<ProcessName>\S+)\:\s{0,4}(?<SyslogMessage>.*)$/
      config_param :time_format, :string, :default => nil # time_format is configurable

      def configure(conf)
        super

        @time_parser = TimeParser.new(@time_format)
      end

      def parse(text)
        record = {}
        format = REGEX.match(text)
        if format
          format.names.each do |key|
            record[key] = format[key]
          end

          event_time = DateTime.parse(record['EventTime']).strftime(@time_format)
          time = @time_parser.parse event_time

          if record['SyslogMessage']
            begin
              # Regex for Device. Example string: naa.60a9800041764b6c463f43786855a3t2
              record['Device'] = record['SyslogMessage'].to_s.match(/naa\.[a-z0-9]{32}/).to_s
              # Regex for SCSI Status. Example string: H:0x8 D:0x0 P:0x0
              record['SCSIStatus'] = record['SyslogMessage'].to_s.match(/\sH\:[a-z0-9]{1,2}x[a-z0-9]{1,2}\sD\:[a-z0-9]{1,2}x[a-z0-9]{1,2}\sP\:[a-z0-9]{1,2}x[a-z0-9]{1,2}\s/).to_s.strip
              if record['ProcessName'] == 'vobd'
                # Regex for ESXI Failure. Example string: [esx.problem.scsi.device.io.latency.high]
                esxifailure = record['SyslogMessage'].to_s.match /\[esx\.problem\.(?<Failure>.*)\]/
                if esxifailure
                  record['ESXIFailure'] = esxifailure['Failure']
                end
              end

              # Regex for VMName, DataCenter, UserName when a VM is created/removed
              details = nil
              if record['SyslogMessage'].match(/.*Removed\s.*\son\s.*\sfrom\s.*/)
                record['Operation'] = 'Delete VM'
                details = record['SyslogMessage'].match(/^.*user=(?<UserName>\S*)\]\s.*Removed\s(?<VMName>.*)\son\s.*\sfrom\s(?<DataCenter>.*).*$/)
              elsif record['SyslogMessage'].match(/.*Created\s.*\son\s.*\sin\s.*/)
                record['Operation'] = 'Create VM'
                details = record['SyslogMessage'].match(/^.*user=(?<UserName>\S*)\]\s.*Created\svirtual\smachine\s(?<VMName>.*)\son\s.*\in\s(?<DataCenter>.*).*$/)
              end

              if !details.nil?
                record['UserName'] = details['UserName']
                record['VMName'] = details['VMName']
                record['DataCenter'] = details['DataCenter']
              end

              # Regex for Storage Latency. Example string: I/O latency increased from average value of 1343 microseconds to 28022 microseconds.
              if ['latency', 'average value', 'microseconds'].all? { |s| record['SyslogMessage'].include? s }
                record['StorageLatency'] = record['SyslogMessage'].match(/to\s[0-9]+\smicroseconds/).to_s.split(' ')[1].to_i
              end
            rescue Exception => e
              OMS::Log.error_once("Unable to parse VMware ESXI log fields: #{e.message}")
            end
          end

          yield time, record
        end
      end
    end
  end
end