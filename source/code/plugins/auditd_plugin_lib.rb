require 'yajl'
require 'securerandom' # SecureRandom.uuid 

require_relative 'oms_common'

module OMS
    class AuditdPlugin

        def initialize(log)
            @log = log
        end

        def transform_and_wrap(event, hostname, time)
            if event.nil?
                @log.error "Transformation of Auditd Plugin input failed; Empty input"
                return nil
            end

            if !event.has_key?("records") or event["records"].nil?
                @log.error "Transformation of Auditd Plugin input failed; Missing field 'records'"
                return nil
            end

            if !event["records"].is_a?(Array) or event["records"].size == 0
                @log.error "Transformation of Auditd Plugin input failed; Invalid 'records' value"
                return nil
            end

            if !event.has_key?("Timestamp") or event["Timestamp"].nil?
                @log.error "Transformation of Auditd Plugin input failed; Missing field 'Timestamp'"
                return nil
            end

            if !event.has_key?("SerialNumber") or event["SerialNumber"].nil?
                @log.error "Transformation of Auditd Plugin input failed; Missing field 'SerialNumber'"
                return nil
            end

            records = []

            event["records"].each do |record|
                if !record.is_a?(Hash) || record.empty?
                    @log.error "Transformation of Auditd Plugin input failed; Invalid data in data record"
                    return nil
                end
                record["Timestamp"] = OMS::Common.format_time(event["Timestamp"].to_f)
                record["AuditID"] = event["Timestamp"] + ":" + event["SerialNumber"].to_s
                record["SerialNumber"] = event["SerialNumber"]
                record["Computer"] = hostname
                if event.has_key?("ProcessFlags")
                    record["ProcessFlags"] = event["ProcessFlags"]
                end
                records.push(record)
            end

            wrapper = {
                "DataType"=>"LINUX_AUDITD_BLOB",
                "IPName"=>"Security",
                "DataItems"=>records
            }

            return wrapper
        end

    end # class
end # module
