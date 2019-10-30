require_relative 'oms_common'
require 'securerandom'
require 'socket'

module OMS
    class ProcessInvestigator

        @@PIVersion = "1.19.0930.0003"

        # The limit for event hub messages is 256k, assuming utf16, that's 128k characters.
        # Leaving some room for overhead, truncate at 100k characters.
        @@MaxResultLength = 100000

        def initialize(log)
            @log = log
        end

        def create_basic_record()
            record = {}
            record["MachineName"] = (Common.get_hostname or "Unknown Host")
            record["OSName"] = "Linux " + (Common.get_os_full_name or "Unknown Distro")
            record["PIVersion"] = @@PIVersion
            record["PICorrelationId"] = SecureRandom.uuid

            return record
        end

        def transform_and_wrap(results)
            alerts = nil
            alert_error = nil
            record = create_basic_record()
            record["PIEventType"] = "Telemetry"

            if results.is_a?(Hash)
                results = results["message"].to_s
            else
                results = results.to_s
            end
            if results.nil? or results.length == 0
                @log.error "Process Investigator Filter failed. Empty message."
                record["PiResults"] = "Process Investigator Filter failed. Empty message."
            else
                # Check for valid guid as session id
                if results[0..35] =~ /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
                    record["SessionId"] = results[0..35]
                    results = (results[37..-1] or "")
                end

                # fetch alerts before truncating the result string
                alerts, alert_error  = get_alert_array(results)

                if results.length > @@MaxResultLength then
                    results = results[0..@@MaxResultLength-1] + " ... TRUNCATED DATA"
                end

                record["PiResults"] = results
            end

            process_investigator_blob = {
                "DataType"=>"PROCESS_INVESTIGATOR_BLOB",
                "IPName"=>"Security",
                "DataItems"=>[record]
            }

            alertParsingError = nil
            if alerts.kind_of?(Array) and alerts.length > 0
                for alert in alerts
                    begin
                        alert["connections"] = []
                        alert_record = create_basic_record()
                        alert_record["PIEventType"] = "Alert"
                        alert_record["SessionId"] = record["SessionId"]
                        alert_record["PiResults"] = alert.to_json
                        process_investigator_blob["DataItems"].push(alert_record)
                    rescue
                        alert_error = "Process Investigator failed to parse alerts: process item malformed"
                    end
                end
            end

            if !alert_error.nil?
                error_record = create_basic_record()
                error_record["PIEventType"] = "Telemetry"
                error_record["SessionId"] = record["SessionId"]
                error_record["PiResults"] = alert_error
                process_investigator_blob["DataItems"].push(error_record)
            end

            @log.info "Processed PI output"
            @log.info process_investigator_blob

            return process_investigator_blob
        end # transform_and_wrap

        def get_alert_array(piResults)
            processList = nil
            errorMsg = nil
            begin
                piResults_parsed = JSON.parse(piResults)
                processList = piResults_parsed['processList']
                if !processList.kind_of?(Array) and processList != ""
                    errorMsg = "Process Investigator failed to parse alerts: processList malformed"
                    processList = nil
                end
            rescue Exception => e
                errorMsg =  "Process Investigator failed to parse alerts: " + e.message
            end
            return processList, errorMsg
        end # get_alert_array

    end # class
end # module

