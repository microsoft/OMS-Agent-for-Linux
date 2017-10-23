require 'json'
require 'securerandom' # SecureRandom.uuid 

require_relative 'oms_common'

module OMS
    class SecurityBaseline

        def initialize(log)
            @log = log
        end

        # ------------------------------------------------------
        def transform_and_wrap(results, hostname, time)
            if results.nil?
                @log.error "Security Baseline Assessment failed; Empty input"
                wrapper = {
                    "DataType"=>"OPERATION_BLOB",
                    "IPName"=>"LogManagement",
                    "DataItems"=>[
                        {
                            "Timestamp" => OMS::Common.format_time(time),
                            "OperationStatus" => "Error",
                            "Computer" => hostname,
                            "Category" => "Security Baseline",
                            "Solution" => "Security",
                            "Detail" => "Security Baseline Assessment failed: Empty output"
                        }
                    ]
                }
                return wrapper, nil
            end

            if results["results"].nil?
                msg = "Security Baseline Assessment failed: Unknown error"
                if results["error"].nil?
                    @log.error "Security Baseline Assessment failed; Invalid input:" + results.inspect
                else
                    @log.error "Security Baseline Assessment failed; " + results["error"]
                    msg = "Security Baseline Assessment failed: " + results["error"]
                end
                wrapper = {
                    "DataType"=>"OPERATION_BLOB",
                    "IPName"=>"LogManagement",
                    "DataItems"=>[
                        {
                            "Timestamp" => OMS::Common.format_time(time),
                            "OperationStatus" => "Error",
                            "Computer" => hostname,
                            "Category" => "Security Baseline",
                            "Solution" => "Security",
                            "Detail" => msg
                        }
                    ]
                }
                return wrapper, nil
            end

            results["assessment_id"] = SecureRandom.uuid      
    
            asm_baseline_results = results["results"]
            scan_time = results["scan_time"]
            assessment_id = results["assessment_id"]

            security_baseline_blob = {
                "DataType"=>"SECURITY_BASELINE_BLOB", 
                "IPName"=>"Security",
                "DataItems"=>[
                ]
            }

            asm_baseline_results.each do |asm_baseline_result|
                if asm_baseline_result["result"] == "MISS" || asm_baseline_result["result"] == "SKIP"
                    next
                end
                
                oms_baseline_result = transform_asm_2_oms(asm_baseline_result, scan_time, hostname, assessment_id)	
                security_baseline_blob["DataItems"].push(oms_baseline_result)
            end 

            security_baseline_summary_blob = calculate_summary(results, hostname, time)

            @log.info "Security Baseline Summary: " + security_baseline_summary_blob.inspect

            return security_baseline_blob, security_baseline_summary_blob
        end # transform_and_wrap
    
        # ------------------------------------------------------   
        def calculate_summary(results, hostname, time)  
            asm_baseline_results = results["results"]
            assessment_id = results["assessment_id"]
            pass_rules = 0;
            critical_failed_rules = 0;
            warning_failed_rules = 0;
            informational_failed_rules = 0;
            all_failed_rules = 0;
    
            asm_baseline_results.each do |asm_baseline_result|

                if asm_baseline_result["result"] == "MISS" || asm_baseline_result["result"] == "SKIP"
                    next 
                end
                
                if asm_baseline_result["result"] == "PASS"
                    pass_rules += 1
                    next 
                end                

                all_failed_rules += 1

                case asm_baseline_result["severity"]
                when "Critical", "Important"
                    critical_failed_rules += 1
                when "Warning"
                    warning_failed_rules += 1
                else
                    informational_failed_rules += 1
                end                   
            end 

            all_assessed_rules = all_failed_rules + pass_rules
            percentage_of_passed_rules = (pass_rules * 100.0 / all_assessed_rules).round
    
            security_baseline_summary_blob = {
                "DataType" => "SECURITY_BASELINE_SUMMARY_BLOB",
                "IPName" => "Security",
                "DataItems" => [
                    {
                        "Computer" => hostname,
                        "TotalAssessedRules" => all_assessed_rules,
                        "CriticalFailedRules" => critical_failed_rules,
                        "WarningFailedRules" => warning_failed_rules,
                        "InformationalFailedRules" => informational_failed_rules,
                        "PercentageOfPassedRules" => percentage_of_passed_rules,
                        "AssessmentId" => assessment_id,
                        "OSName" => "Linux",
                        "BaselineType" => "Linux"
                    }
                ] 
            }

            return security_baseline_summary_blob
        end # calculate_summary 

        # ------------------------------------------------------
        def transform_asm_2_oms(asm_baseline_result, scan_time, host, assessment_id)
            oms = {
                "TimeAnalyzed" => scan_time,
                "Computer" => host,
                "CceId"=> asm_baseline_result["cceid"],
                "Severity" => asm_baseline_result["severity"] == "Important" ? "Critical" : asm_baseline_result["severity"],
                "Name" => asm_baseline_result["description"],
                "AnalyzeResult" => asm_baseline_result["result"] == "PASS" ? "Passed" : "Failed",
                "AssessmentId" => assessment_id,
                "OSName" => "Linux",
                "RuleType" => "Command",
                "RuleId" => asm_baseline_result["ruleId"],
                "BaselineType" => "Linux",
                "ActualResult" => asm_baseline_result["error_text"]
            }
            return oms
        end # transform_asm_2_oms
    end # class
end # module
