require_relative 'oms_common'
require 'securerandom'
require 'socket'

module OMS
    class ProcessInvestigator

        def initialize(log)
            @log = log
        end

        # ------------------------------------------------------
        def transform_and_wrap(results)
            # The limit for event hub messages is 256k, assuming utf16, that's 128k characters.
            # Leaving some room for overhead, truncate at 100k characters.
            maxResultLength = 100000
            record = {}
            record["PIEventType"] = "Telemetry"
            record["MachineName"] = (Common.get_hostname or "Unknown Host")
            record["OSName"] = "Linux " + (Common.get_os_full_name or "Unknown Distro")
            record["PIVersion"] = "1.19.0930.0003"
            record["PICorrelationId"] = SecureRandom.uuid


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
                if results.length > maxResultLength then
                    results = results[0..maxResultLength-1] + " ... TRUNCATED DATA"
                end

                record["PiResults"] = results
            end

            process_investigator_blob = {
                "DataType"=>"PROCESS_INVESTIGATOR_BLOB", 
                "IPName"=>"Security",
                "DataItems"=>[record]
            }

            @log.info "Processed PI output"
            @log.info process_investigator_blob

            return process_investigator_blob
        end # transform_and_wrap
    end # class
end # module

