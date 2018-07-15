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

    def test_docker_baseline_with_correct_input

        baseline_results_str = '{
	"baseline_id": "OMS.Docker.Linux.1",
	"base_orig_id": "1",
	"setting_count": 16,
	"scan_time": "2018-06-27T14:00:27.208354811+01:00",
	"error": "",
	"results": [{
		"msid": "1.3",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-1-3",
		"severity": "Critical",
		"description": "Ensure docker version is up-to-date",
		"ruleId": "23d52f96-7ba6-45ef-8fa4-0251805d4896"
	},
	{
		"msid": "1.5",
		"result": "FAIL",
		"error_text": "",
		"cceid": "CIS-CE-1-5",
		"severity": "Warning",
		"description": "Ensure auditing is configured for the docker daemon",
		"ruleId": "505207ac-8ff4-42e4-81eb-7c5b7d96e696"
	},
	{
		"msid": "1.6",
		"result": "MISS",
		"error_text": "",
		"cceid": "CIS-CE-1-6",
		"severity": "Warning",
		"description": "Ensure auditing is configured for Docker files and directories - /var/lib/docker",
		"ruleId": "89ba197c-e67b-4d91-b441-5b1e552847a5"
	},
	{
		"msid": "1.7",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-1-7",
		"severity": "Warning",
		"description": "Ensure auditing is configured for Docker files and directories - /etc/docker",
		"ruleId": "b10dcd00-7461-46b9-a71e-21531216cb5d"
	},
	{
		"msid": "1.8",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-1-8",
		"severity": "Warning",
		"description": "Ensure auditing is configured for Docker files and directories - docker.service",
		"ruleId": "62063e9a-c9ce-4167-b4e2-a2536a515947"
	},
	{
		"msid": "1.9",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-1-9",
		"severity": "Warning",
		"description": "Ensure auditing is configured for Docker files and directories - docker.socket",
		"ruleId": "358eadc8-57f6-4b4e-a874-1999e8a80a17"
	},
	{
		"msid": "1.10",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-1-10",
		"severity": "Warning",
		"description": "Ensure auditing is configured for Docker files and directories - /etc/default/docker",
		"ruleId": "07982b8f-5697-45ad-93dc-786273aa4ba1"
	},
	{
		"msid": "1.11",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-1-11",
		"severity": "Warning",
		"description": "Ensure auditing is configured for Docker files and directories - /etc/docker/daemon.json",
		"ruleId": "a2a9eaaf-8571-4be3-8d04-c0db00e78125"
	},
	{
		"msid": "1.12",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-1-12",
		"severity": "Warning",
		"description": "Ensure auditing is configured for Docker files and directories - /usr/bin/docker-containerd",
		"ruleId": "db3d50cf-a60c-4b11-a09f-409ee45401b8"
	},
	{
		"msid": "1.13",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-1-13",
		"severity": "Warning",
		"description": "Ensure auditing is configured for Docker files and directories - /usr/bin/docker-runc",
		"ruleId": "7b2cdabf-f4c3-4e69-9af9-b65c3e2edae9"
	},
	{
		"msid": "2.1",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-2-1",
		"severity": "Critical",
		"description": "Ensure network traffic is restricted between containers on the default bridge",
		"ruleId": "f30a6a51-9f47-4d3b-819d-7edf7fb53eb4"
	},
	{
		"msid": "2.4",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-2-4",
		"severity": "Critical",
		"description": "Ensure insecure registries are not used",
		"ruleId": "63a6efd7-8465-4a9d-a979-ed82db21fb6d"
	},
	{
		"msid": "2.5",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-2-5",
		"severity": "Critical",
		"description": "The aufs storage driver should not be used by the docker daemon",
		"ruleId": "3b964bc7-584b-43fa-87aa-c84cda32c1c5"
	},
	{
		"msid": "2.7",
		"result": "FAIL",
		"error_text": "Output of [/usr/bin/docker container ls --quiet --all | xargs --no-run-if-empty /usr/bin/docker container inspect] should not match regex [Ulimits and null]:             \"Ulimits\": null,",
		"cceid": "CIS-CE-2-7",
		"severity": "Warning",
		"description": "Ensure the default ulimit is configured appropriately",
		"ruleId": "783e2e24-d659-4292-ae88-6cecc861ac3f"
	},
	{
		"msid": "2.10",
		"result": "PASS",
		"error_text": "",
		"cceid": "CIS-CE-2-10",
		"severity": "Warning",
		"description": "Ensure base device size is not changed until needed",
		"ruleId": "9cdefd3a-f2ea-4cd5-a807-30d2551eb45f"
	},
	{
		"msid": "4.1",
		"result": "FAIL",
		"error_text": "Output of [/usr/bin/docker container ls --quiet --all | xargs --no-run-if-empty /usr/bin/docker container inspect] should not match regex [\"User\" and \"0\"|\"root\"|\"\"]",
            "cceid": "CIS-CE-4-1",
            "severity": "Warning",
            "description": "Ensureauserforthecontainerhasbeencreated",
            "ruleId": "344e58e2-95d7-4c37-981c-c246be90ce8d"
        }
    ]
}'

        baseline_results_json = JSON.parse(baseline_results_str)

        baseline_results_json["assessment_id"] = "b6cb42ac-e853-4ee1-a5f4-a66d82347ce5"

        security_baseline = OMS::SecurityBaseline.new(OMS::MockLog.new, 'Docker')
        security_baseline_blob, security_baseline_summary_blob = security_baseline.transform_and_wrap(baseline_results_json, "test_host", "")

        assert_equal("SECURITY_BASELINE_BLOB", security_baseline_blob["DataType"], "Incorrect 'DataType' value")
        assert_equal("Security", security_baseline_blob["IPName"], "Incorrect 'IPName' value")

        baseline_item_0 = security_baseline_blob["DataItems"][0]
        assert_equal("2018-06-27T14:00:27.208354811+01:00", baseline_item_0["TimeAnalyzed"], "Incorrect 'TimeAnalyzed' value")
        assert_equal("test_host", baseline_item_0["Computer"], "Incorrect 'Computer' value")
        assert_equal("CIS-CE-1-3", baseline_item_0["CceId"], "Incorrect 'CceId' value")
        assert_equal("Critical", baseline_item_0["Severity"], "Incorrect 'Severity' value")
        assert_equal("Ensure docker version is up-to-date", baseline_item_0["Name"], "Incorrect 'Name' value")
        assert_equal("Passed", baseline_item_0["AnalyzeResult"], "Incorrect 'AnalyzeResult' value")
        assert_equal("23d52f96-7ba6-45ef-8fa4-0251805d4896", baseline_item_0["RuleId"], "Incorrect 'RuleId' value")
        assert_not_equal("b6cb42ac-e853-4ee1-a5f4-a66d82347ce5", baseline_item_0["AssessmentId"], "Incorrect 'AssessmentId' value")
        assert_equal("Linux", baseline_item_0["OSName"], "Incorrect 'OSName' value")
        assert_equal("Command", baseline_item_0["RuleType"], "Incorrect 'RuleType' value")
        assert_equal("Docker", baseline_item_0["BaselineType"], "Incorrect 'BaselineType' value")

        baseline_item_1 = security_baseline_blob["DataItems"][1]
        assert_equal("2018-06-27T14:00:27.208354811+01:00", baseline_item_1["TimeAnalyzed"], "Incorrect 'TimeAnalyzed' value")
        assert_equal("test_host", baseline_item_1["Computer"], "Incorrect 'Computer' value")
        assert_equal("CIS-CE-1-5", baseline_item_1["CceId"], "Incorrect 'CceId' value")
        assert_equal("Warning", baseline_item_1["Severity"], "Incorrect 'Severity' value")
        assert_equal("Ensure auditing is configured for the docker daemon", baseline_item_1["Name"], "Incorrect 'Name' value")
        assert_equal("Failed", baseline_item_1["AnalyzeResult"], "Incorrect 'AnalyzeResult' value")
        assert_equal("505207ac-8ff4-42e4-81eb-7c5b7d96e696", baseline_item_1["RuleId"], "Incorrect 'RuleId' value")
        assert_not_equal("b6cb42ac-e853-4ee1-a5f4-a66d82347ce5", baseline_item_1["AssessmentId"], "Incorrect 'AssessmentId' value")
        assert_equal("Linux", baseline_item_1["OSName"], "Incorrect 'OSName' value")
        assert_equal("Command", baseline_item_1["RuleType"], "Incorrect 'RuleType' value")
        assert_equal("Docker", baseline_item_1["BaselineType"], "Incorrect 'BaselineType' value")

        # Skip rule with MISS result
        baseline_item_2 = security_baseline_blob["DataItems"][2]
        assert_equal("2018-06-27T14:00:27.208354811+01:00", baseline_item_2["TimeAnalyzed"], "Incorrect 'TimeAnalyzed' value")
        assert_equal("test_host", baseline_item_2["Computer"], "Incorrect 'Computer' value")
        assert_equal("CIS-CE-1-7", baseline_item_2["CceId"], "Incorrect 'CceId' value")

        assert_equal("SECURITY_BASELINE_SUMMARY_BLOB", security_baseline_summary_blob["DataType"], "Incorrect 'DataType' value")
        assert_equal("Security", security_baseline_summary_blob["IPName"], "Incorrect 'IPName' value")

        baseline_summary_item = security_baseline_summary_blob["DataItems"][0]
        assert_equal("test_host", baseline_summary_item["Computer"], "Incorrect 'Computer' value")
        assert_equal(15, baseline_summary_item["TotalAssessedRules"], "Incorrect 'TotalAssessedRules' value")
        assert_equal(0, baseline_summary_item["CriticalFailedRules"], "Incorrect 'CriticalFailedRules' value")
        assert_equal(3, baseline_summary_item["WarningFailedRules"], "Incorrect 'WarningFailedRules' value")
        assert_equal(0, baseline_summary_item["InformationalFailedRules"], "Incorrect 'InformationalFailedRules' value")
        assert_equal(80, baseline_summary_item["PercentageOfPassedRules"], "Incorrect 'PercentageOfPassedRules' value")
        assert_not_equal("b6cb42ac-e853-4ee1-a5f4-a66d82347ce5", baseline_summary_item["AssessmentId"], "Incorrect 'AssessmentId' value")
        assert_equal("Linux", baseline_summary_item["OSName"], "Incorrect 'OSName' value")
        assert_equal("Docker", baseline_summary_item["BaselineType"], "Incorrect 'BaselineType' value")

        assert_equal(baseline_item_0["AssessmentId"], baseline_summary_item["AssessmentId"], "Different 'AssessmentId' between baseline and baseline summary")
    end

    def test_docker_baseline_with_empty_input
        baseline_results_json = nil

        security_baseline = OMS::SecurityBaseline.new(OMS::MockLog.new, "Docker")
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

    def test_docker_baseline_with_bad_input
        baseline_results_str = '{ "baseline_id": "OMS.Linux.Docker.1" }'
        baseline_results_json = JSON.parse(baseline_results_str)

        security_baseline = OMS::SecurityBaseline.new(OMS::MockLog.new, "Docker")
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

    def test_docker_baseline_with_error_input
        baseline_results_str = '{ "error": "test error" }'
        baseline_results_json = JSON.parse(baseline_results_str)

        security_baseline = OMS::SecurityBaseline.new(OMS::MockLog.new, "Docker")
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

