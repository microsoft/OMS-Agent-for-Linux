require 'yajl'
require 'securerandom' # SecureRandom.uuid 

require_relative 'oms_common'

module OMS
    class AuditdPlugin

        def initialize(log)
            @log = log
        end

        def transform_and_wrap(record, hostname, time)
            if record.nil?
                @log.error "Transformation of Auditd Plugin input failed; Empty input"
                return nil
            end

            if !record.has_key?("record-count")
                @log.error "Transformation of Auditd Plugin input failed; Missing field 'record-count'"
                return nil
            end

            if record["record-count"] <= 0
                @log.error "Transformation of Auditd Plugin input failed; Invalid 'record-count' value"
                return nil
            end

            if !record.has_key?("Timestamp")
                @log.error "Transformation of Auditd Plugin input failed; Missing field 'Timestamp'"
                return nil
            end
            if !record.has_key?("SerialNumber")
                @log.error "Transformation of Auditd Plugin input failed; Missing field 'SerialNumber'"
                return nil
            end

            records = []

            for ridx in 1..record["record-count"]
                rname = "record-data-"+(ridx-1).to_s
                if !record.has_key?(rname)
                    @log.error "Transformation of Auditd Plugin input failed; Missing field '" + rname + "'"
                    return nil
                end
                rdata = Yajl::Parser.parse(record[rname])
                if !rdata.is_a?(Hash) || rdata.empty?
                    @log.error "Transformation of Auditd Plugin input failed; Invalid data in data field '" + rname + "'"
                    return nil
                end
                rdata["Timestamp"] = OMS::Common.format_time(record["Timestamp"].to_f)
                rdata["AuditID"] = record["Timestamp"] + ":" + record["SerialNumber"].to_s
                rdata["SerialNumber"] = record["SerialNumber"]
                rdata["Computer"] = hostname
                records.push(rdata)
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
