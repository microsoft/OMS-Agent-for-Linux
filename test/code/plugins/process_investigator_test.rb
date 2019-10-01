require 'test/unit'
require_relative 'omstestlib'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/process_investigator_lib'

class ProcessInvestigatorLibTest < Test::Unit::TestCase

    @@expectedMachineName = (OMS::Common.get_hostname or "Unknown Host")
    @@expectedOSName = "Linux " + (OMS::Common.get_os_full_name or "Unknown Distro")
    @@expectedPIVersion = "1.19.0930.0003"
    @@sampleSessionId = "11223344-5566-7788-9900-aabbccddeeff"

    def test_process_investigator_regular_output
        pi_results = '{"ldpreload":{"PreloadClassification":"Clean","PreloadEnvVarExists":false,"PreloadEnvVarValue":[],"PreloadFileAnalysis":"","PreloadFileExists":false,"PreloadFileValue":[]},"logs":"","machine":{"AlsrVal":2,"AlsrValAsExpected":true,"DistroName":"NAME=\"Ubuntu\"","DistroVersion":"VERSION=\"16.04.6 LTS (Xenial Xerus)\"","DmesgVal":0,"DmesgValAsExpected":false,"KernalAddrDisplayVal":1,"KernalAddrDisplayValAsExpected":true,"KernelRelease":"4.4.0-159-generic","KernelVersion":"#187-Ubuntu SMP Thu Aug 1 16:28:06 UTC 2019","MachineArch":"x86_64","NodeName":"DevUbuntu16","PtraceVal":1,"PtraceValAsExpected":true,"SystemName":"Linux","osType":"Linux"},"processList":"","scanSummary":{"CpuTimeInSec":0.168043,"CpuUsagePreAnalysisInPercent":51.02040816326531,"Euid":0,"EuidName":"root","FoundBenign":false,"FoundInformational":true,"FoundKnownMalicious":false,"FoundMalicious":false,"FoundSuspicious":false,"InformationalCount":1,"KernelTimeInSec":0.084,"MaliciousCount":0,"ScanMode":"Periodic","ScanTimestamp":"Mon Sep 30 15:04:38 2019","SuspiciousCount":0,"TotalTaskCount":168,"Uid":0,"UserTimeInSec":0.084,"VmPeakinKB":21984,"WallTimeInSec":0.169,"scanOutcome":"ScanCompleted","version":"1.0.0.0"}}'
    	pi_filter_msg = {"message" => @@sampleSessionId + " " + pi_results}
        pi_result = run_basic_pi_test(pi_filter_msg, @@sampleSessionId)

        pi_result_json=nil
        assert_nothing_raised do pi_result_json = JSON.parse(pi_result) end
        assert_not_equal("", pi_result_json.to_s, "Empty 'PiResults' value")
    end

    def test_process_investigator_nullsessionid_errormessage
        expected_session_id = "00000000-0000-0000-0000-000000000000"
        pi_filter_msg = {"message" => expected_session_id + " Unhandled timeout in PI."}
        pi_result = run_basic_pi_test(pi_filter_msg, expected_session_id)

        assert_equal("Unhandled timeout in PI.", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_nil_message
        pi_result = run_basic_pi_test(nil)

        assert_equal("Process Investigator Filter failed. Empty message.", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_empty_string_message
         pi_result = run_basic_pi_test("")

         assert_equal("Process Investigator Filter failed. Empty message.", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_string_message
        pi_result = run_basic_pi_test("Test String")

        assert_equal("Test String", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_int_message
        pi_result = run_basic_pi_test(123)

        assert_equal("123", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_empty_message
        pi_filter_msg = {"message" => ""}
        pi_result = run_basic_pi_test(pi_filter_msg)

        assert_equal("Process Investigator Filter failed. Empty message.", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_empty_results_no_space
        pi_filter_msg = {"message" => @@sampleSessionId}
        pi_result = run_basic_pi_test(pi_filter_msg, @@sampleSessionId)

        assert_equal("", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_empty_results_with_space
        pi_filter_msg = {"message" => @@sampleSessionId + " "}
        pi_result = run_basic_pi_test(pi_filter_msg, @@sampleSessionId)

        assert_equal("", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_single_char_result
        pi_filter_msg = {"message" => @@sampleSessionId + " A"}
        pi_result = run_basic_pi_test(pi_filter_msg, @@sampleSessionId)

        assert_equal("A", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_invalid_sessionid
        pi_filter_msg = {"message" => "11223344-5566-7788-9900-aabbccddefg Test"}
        pi_result = run_basic_pi_test(pi_filter_msg)

        assert_equal("11223344-5566-7788-9900-aabbccddefg Test", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_empty_short_result_no_sessionid
        pi_filter_msg = {"message" => "Short Test"}
        pi_result = run_basic_pi_test(pi_filter_msg)

        assert_equal("Short Test", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_empty_long_result_no_sessionid
        pi_filter_msg = {"message" => "Long result, this line is more than 36 characters, the length of a uuid."}
        pi_result = run_basic_pi_test(pi_filter_msg)

        assert_equal("Long result, this line is more than 36 characters, the length of a uuid.", pi_result, "Incorrect 'PiResults' value")
    end

    def test_process_investigator_truncated
        # create string of over 100k '0' characters
        pi_filter_msg = {"message" => @@sampleSessionId + " " + "".rjust(111111, "0")}
        pi_result = run_basic_pi_test(pi_filter_msg, @@sampleSessionId)

        assert_match(/^0{100000} \.\.\. TRUNCATED DATA$/, pi_result, "Incorrect 'PiResults' value")
    end

    def run_basic_pi_test(filter_data, expected_session_id = nil)

        pi = OMS::ProcessInvestigator.new(OMS::MockLog.new)
        pi_blob = pi.transform_and_wrap(filter_data)

        assert_equal("PROCESS_INVESTIGATOR_BLOB", pi_blob["DataType"], "Incorrect 'DataType' value")
        assert_equal("Security", pi_blob["IPName"], "Incorrect 'IPName' value")

        pi_item = pi_blob["DataItems"][0]
        assert_equal("Telemetry", pi_item["PIEventType"], "Incorrect 'PIEventType' value")
        assert_equal(@@expectedMachineName, pi_item["MachineName"], "Incorrect 'MachineName' value")
        assert_equal(@@expectedOSName, pi_item["OSName"], "Incorrect 'OSName' value")
        assert_equal(@@expectedPIVersion, pi_item["PIVersion"], "Incorrect 'PIVersion' value")
        assert_match(/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/, pi_item["PICorrelationId"], "Incorrect 'PICorrelationId' format")

        if expected_session_id.nil?
            assert_nil(pi_item["SessionId"], "Incorrect 'SessionId' value")
        else
            assert_equal(expected_session_id, pi_item["SessionId"], "Incorrect 'SessionId' value")
        end
        return pi_item["PiResults"]
    end
end
