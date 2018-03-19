require 'test/unit'
require_relative 'omstestlib'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/security_baseline_lib'

class BaselineLibTest < Test::Unit::TestCase
    
    def test_baseline_with_correct_input

        baseline_results_str = '{ "baseline_id": "OMS.Linux.1", "base_orig_id": "1", "setting_count": 6, "scan_time": "2016-09-21T10:19:00.66205592Z","results": [ {"msid": "2.1","result": "PASS","error_text": "","cceid": "CCE-3522-0","severity": "Important","description": "The nodev option should be enabled for all removable media.","ruleId": "5c7537f2-b90b-44a4-89c9-4fca5fd79ef7"},{"msid": "2.2","result": "FAIL","error_text": "","cceid": "CCE-4275-4","severity": "Warning","description": "The noexec option should be enabled for all removable media.","ruleId": "7976cc38-fddb-4913-9295-4fcac2e641c3"},{"msid": "2.3","result": "MISS","error_text": "","cceid": "CCE-4042-8","severity": "Important","description": "The nosuid option should be enabled for all removable media.","ruleId": "cdc390c9-fb4a-47f6-90a7-4e1bd6d0e9e6"},{"msid": "5","result": "FAIL","error_text": "","cceid": "CCE-4368-7","severity": "Critical","description": "The nodev-nosuid option should be enabled for all NFS mounts.","ruleId": "7ca24433-3c08-4ff5-9fe2-d8e1830c5829"}, {"msid": "7","result": "FAIL","error_text": "No patches needed","cceid": "CCE-XXXXX-1","severity": "Informational","description": "All available package updates should be installed.","ruleId": "5e0a757f-66f0-4233-a857-efee34906f14"},{"msid": "77","result": "FAIL","error_text": "","cceid": "CCE-4308-3","severity": "Important","description": "The rsh-server package should be uninstalled.","ruleId": "b256491f-f804-4c44-bfa4-057dd2f44c30"}] }'
        baseline_results_json = JSON.parse(baseline_results_str)

        baseline_results_json["assessment_id"] = "3af00be8-44b9-4925-a64a-d5fd3241ddd3"
        
        security_baseline = OMS::SecurityBaseline.new(OMS::MockLog.new)
        security_baseline_blob, security_baseline_summary_blob = security_baseline.transform_and_wrap(baseline_results_json, "test_host", "")        
        
        assert_equal("SECURITY_BASELINE_BLOB", security_baseline_blob["DataType"], "Incorrect 'DataType' value") 
        assert_equal("Security", security_baseline_blob["IPName"], "Incorrect 'IPName' value")
        
        baseline_item_0 = security_baseline_blob["DataItems"][0]
        assert_equal("2016-09-21T10:19:00.66205592Z", baseline_item_0["TimeAnalyzed"], "Incorrect 'TimeAnalyzed' value")
        assert_equal("test_host", baseline_item_0["Computer"], "Incorrect 'Computer' value")
        assert_equal("CCE-3522-0", baseline_item_0["CceId"], "Incorrect 'CceId' value")
        assert_equal("Critical", baseline_item_0["Severity"], "Incorrect 'Severity' value")
        assert_equal("The nodev option should be enabled for all removable media.", baseline_item_0["Name"], "Incorrect 'Name' value")
        assert_equal("Passed", baseline_item_0["AnalyzeResult"], "Incorrect 'AnalyzeResult' value")
        assert_equal("5c7537f2-b90b-44a4-89c9-4fca5fd79ef7", baseline_item_0["RuleId"], "Incorrect 'RuleId' value")
        assert_not_equal("3af00be8-44b9-4925-a64a-d5fd3241ddd3", baseline_item_0["AssessmentId"], "Incorrect 'AssessmentId' value")
        assert_equal("Linux", baseline_item_0["OSName"], "Incorrect 'OSName' value")
        assert_equal("Command", baseline_item_0["RuleType"], "Incorrect 'RuleType' value")
        
        baseline_item_1 = security_baseline_blob["DataItems"][1]
        assert_equal("2016-09-21T10:19:00.66205592Z", baseline_item_1["TimeAnalyzed"], "Incorrect 'TimeAnalyzed' value")
        assert_equal("test_host", baseline_item_1["Computer"], "Incorrect 'Computer' value")
        assert_equal("CCE-4275-4", baseline_item_1["CceId"], "Incorrect 'CceId' value")
        assert_equal("Warning", baseline_item_1["Severity"], "Incorrect 'Severity' value")
        assert_equal("The noexec option should be enabled for all removable media.", baseline_item_1["Name"], "Incorrect 'Name' value")
        assert_equal("Failed", baseline_item_1["AnalyzeResult"], "Incorrect 'AnalyzeResult' value")
        assert_equal("7976cc38-fddb-4913-9295-4fcac2e641c3", baseline_item_1["RuleId"], "Incorrect 'RuleId' value")        
        assert_not_equal("3af00be8-44b9-4925-a64a-d5fd3241ddd3", baseline_item_1["AssessmentId"], "Incorrect 'AssessmentId' value")
        assert_equal("Linux", baseline_item_1["OSName"], "Incorrect 'OSName' value")        
        assert_equal("Command", baseline_item_1["RuleType"], "Incorrect 'RuleType' value")

        # Skip rule with MISS result
        baseline_item_2 = security_baseline_blob["DataItems"][2]
        assert_equal("2016-09-21T10:19:00.66205592Z", baseline_item_2["TimeAnalyzed"], "Incorrect 'TimeAnalyzed' value")
        assert_equal("test_host", baseline_item_2["Computer"], "Incorrect 'Computer' value")
        assert_equal("CCE-4368-7", baseline_item_2["CceId"], "Incorrect 'CceId' value")

        assert_equal("SECURITY_BASELINE_SUMMARY_BLOB", security_baseline_summary_blob["DataType"], "Incorrect 'DataType' value") 
        assert_equal("Security", security_baseline_summary_blob["IPName"], "Incorrect 'IPName' value")
        
        baseline_summary_item = security_baseline_summary_blob["DataItems"][0]
        assert_equal("test_host", baseline_summary_item["Computer"], "Incorrect 'Computer' value")
        assert_equal(5, baseline_summary_item["TotalAssessedRules"], "Incorrect 'TotalAssessedRules' value")
        assert_equal(2, baseline_summary_item["CriticalFailedRules"], "Incorrect 'CriticalFailedRules' value")
        assert_equal(1, baseline_summary_item["WarningFailedRules"], "Incorrect 'WarningFailedRules' value")
        assert_equal(1, baseline_summary_item["InformationalFailedRules"], "Incorrect 'InformationalFailedRules' value")
        assert_equal(20, baseline_summary_item["PercentageOfPassedRules"], "Incorrect 'PercentageOfPassedRules' value")
        assert_not_equal("3af00be8-44b9-4925-a64a-d5fd3241ddd3", baseline_summary_item["AssessmentId"], "Incorrect 'AssessmentId' value")
        assert_equal("Linux", baseline_summary_item["OSName"], "Incorrect 'OSName' value")
        
        assert_equal(baseline_item_0["AssessmentId"], baseline_summary_item["AssessmentId"], "Different 'AssessmentId' between baseline and baseline summary")
    end

    def test_baseline_with_empty_input
        baseline_results_json = nil
      
        security_baseline = OMS::SecurityBaseline.new(OMS::MockLog.new)
        security_baseline_blob, security_baseline_summary_blob = security_baseline.transform_and_wrap(baseline_results_json, "test_host", 0)
        
        assert_equal(nil, security_baseline_summary_blob, "Incorrect error case support")
        
        assert_equal("OPERATION_BLOB", security_baseline_blob["DataType"], "Incorrect 'DataType' value")
        assert_equal("LogManagement", security_baseline_blob["IPName"], "Incorrect 'IPName' value")
        item_0 = security_baseline_blob["DataItems"][0]
        assert_equal("1970-01-01T00:00:00.000Z", item_0["Timestamp"], "Incorrect 'Timestamp' value")
        assert_equal("Error", item_0["OperationStatus"], "Incorrect 'OperationStatus' value")
        assert_equal("test_host", item_0["Computer"], "Incorrect 'Computer' value")
        assert_equal("Security Baseline", item_0["Category"], "Incorrect 'Category' value")
        assert_equal("Security", item_0["Solution"], "Incorrect 'Solution' value")
        assert_equal("Security Baseline Assessment failed: Empty output", item_0["Detail"], "Incorrect 'Detail' value")
    end

    def test_baseline_with_bad_input
        baseline_results_str = '{ "baseline_id": "OMS.Linux.1" }'    
        baseline_results_json = JSON.parse(baseline_results_str)

        security_baseline = OMS::SecurityBaseline.new(OMS::MockLog.new)        
        security_baseline_blob, security_baseline_summary_blob = security_baseline.transform_and_wrap(baseline_results_json, "test_host", 0)        
        
        assert_equal(nil, security_baseline_summary_blob, "Incorrect error case support")
        
        assert_equal("OPERATION_BLOB", security_baseline_blob["DataType"], "Incorrect 'DataType' value")
        assert_equal("LogManagement", security_baseline_blob["IPName"], "Incorrect 'IPName' value")
        item_0 = security_baseline_blob["DataItems"][0]
        assert_equal("1970-01-01T00:00:00.000Z", item_0["Timestamp"], "Incorrect 'Timestamp' value")
        assert_equal("Error", item_0["OperationStatus"], "Incorrect 'OperationStatus' value")
        assert_equal("test_host", item_0["Computer"], "Incorrect 'Computer' value")
        assert_equal("Security Baseline", item_0["Category"], "Incorrect 'Category' value")
        assert_equal("Security", item_0["Solution"], "Incorrect 'Solution' value")
        assert_equal("Security Baseline Assessment failed: Unknown error", item_0["Detail"], "Incorrect 'Detail' value")
    end

    def test_baseline_with_error_input
        baseline_results_str = '{ "error": "test error" }'
        baseline_results_json = JSON.parse(baseline_results_str)

        security_baseline = OMS::SecurityBaseline.new(OMS::MockLog.new)        
        security_baseline_blob, security_baseline_summary_blob = security_baseline.transform_and_wrap(baseline_results_json, "test_host", 0)

        assert_equal(nil, security_baseline_summary_blob, "Incorrect error case support")
        
        assert_equal("OPERATION_BLOB", security_baseline_blob["DataType"], "Incorrect 'DataType' value")
        assert_equal("LogManagement", security_baseline_blob["IPName"], "Incorrect 'IPName' value")
        item_0 = security_baseline_blob["DataItems"][0]
        assert_equal("1970-01-01T00:00:00.000Z", item_0["Timestamp"], "Incorrect 'Timestamp' value")
        assert_equal("Error", item_0["OperationStatus"], "Incorrect 'OperationStatus' value")
        assert_equal("test_host", item_0["Computer"], "Incorrect 'Computer' value")
        assert_equal("Security Baseline", item_0["Category"], "Incorrect 'Category' value")
        assert_equal("Security", item_0["Solution"], "Incorrect 'Solution' value")
        assert_equal("Security Baseline Assessment failed: test error", item_0["Detail"], "Incorrect 'Detail' value")
        
    end
end
