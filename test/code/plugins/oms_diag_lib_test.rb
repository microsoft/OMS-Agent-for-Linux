require 'test/unit'
require 'fluent/test'
require 'securerandom'
require_relative 'in_diag_tester'
require_relative '../../../source/code/plugins/oms_diag_lib'

class OMSDiagUT < Test::Unit::TestCase

    class OMS::Diag
        @@InstallInfoPath = "test_version_file.txt"
        class << self
            def SetDiagSupported(val)
                @@DiagSupported = val
            end
            def GetInstallInfoPath()
                @@InstallInfoPath
            end
        end
    end

    def setup
        Fluent::Test.setup
        OMS::Diag.SetDiagSupported(true)
    end

    def teardown
        super
        Fluent::Engine.stop
        File.unlink(OMS::Diag.GetInstallInfoPath()) if File.exist?(OMS::Diag.GetInstallInfoPath())
    end

    def create_driver
        _d = Fluent::Test::InputTestDriver.new(Fluent::DiagTest)
    end

    def get_emitted_log_for_logtype(logType)
        _d = create_driver()
        _d.instance.diag_log_type = logType
        _d.run
        _d.emits
    end

    # Test cases pertaining to log emission

    # Checking if simple log alone emission is valid
    def test_case_log_emission_01
        log_emits = get_emitted_log_for_logtype(Fluent::DiagTest::LOG_TYPE_01)
        assert(log_emits.length > 0, "At least one log emit should occur")
        log_emits.each do |(tag, t, x)|
            assert_equal(true,
                         OMS::Diag.IsValidDataItem?(x),
                         "All emitted dataitem from diag should be valid")
            assert_equal(Fluent::DiagTest::LOG_STR_01,
                         x[OMS::Diag::DI_KEY_LOGMESSAGE],
                         "The emitted log did not match with one intended")
        end
    end

    # Checking if log emission along with ipname is valid
    def test_case_log_emission_02
        log_emits = get_emitted_log_for_logtype(Fluent::DiagTest::LOG_TYPE_02)
        assert(log_emits.length > 0, "At least one log emit should occur")
        log_emits.each do |(tag, t, x)|
            assert_equal(true,
                         OMS::Diag.IsValidDataItem?(x),
                         "All emitted dataitem from diag should be valid")
            assert_equal(Fluent::DiagTest::LOG_STR_02,
                         x[OMS::Diag::DI_KEY_LOGMESSAGE],
                         "The emitted log did not match with one intended")
            assert_equal(Fluent::DiagTest::LOG_IPNAME,
                         x[OMS::Diag::DI_KEY_IPNAME],
                         "The ipname does not match with the one intended")
        end
    end

    # Checking if log emission along with optional properties is valid
    def test_case_log_emission_03
        log_emits = get_emitted_log_for_logtype(Fluent::DiagTest::LOG_TYPE_03)
        assert(log_emits.length > 0, "At least one log emit should occur")
        log_emits.each do |(tag, t, x)|
            assert_equal(true,
                         OMS::Diag.IsValidDataItem?(x),
                         "All emitted dataitem from diag should be valid")
            assert_equal(Fluent::DiagTest::LOG_STR_03,
                         x[OMS::Diag::DI_KEY_LOGMESSAGE],
                         "The emitted log did not match with one intended")
            assert_equal(OMS::Diag::DEFAULT_IPNAME,
                         x[OMS::Diag::DI_KEY_IPNAME],
                         "The ipname does not match with the one intended")
            # Check if keys corresponding to those sent match
            Fluent::DiagTest::LOG_PROPERTIES_FOR_03.each do |key, value|
                assert_equal(true, x.key?(key),
                            "Emitted dataitem should have key #{key}")
                assert_equal(Fluent::DiagTest::LOG_PROPERTIES_FOR_03[key],
                             x[key],
                             "Emitted dataitem has wrong value for key #{key}")
            end
        end
    end

    # Checking if optional properties override mandatory ones (should not)
    def test_case_log_emission_04
        log_emits = get_emitted_log_for_logtype(Fluent::DiagTest::LOG_TYPE_04)
        assert(log_emits.length > 0, "At least one log emit should occur")
        log_emits.each do |(tag, t, x)|
            assert_equal(true,
                         OMS::Diag.IsValidDataItem?(x),
                         "All emitted dataitem from diag should be valid")
            assert_equal(Fluent::DiagTest::LOG_STR_04,
                         x[OMS::Diag::DI_KEY_LOGMESSAGE],
                         "The emitted log did not match with one intended")
            assert_equal(OMS::Diag::DEFAULT_IPNAME,
                         x[OMS::Diag::DI_KEY_IPNAME],
                         "The ipname does not match with the one intended")
        end
    end

    # Test cases pertaining to dataitem processing

    # Checking if ProcessDataItemsPostAggregation is working correctly
    def test_case_dataitem_proc_01
        agent_id = 'test-agent-id-1234'
        # Creating valid dataitems
        dataitems = Array.new
        (1..5).each do
            dataitem = Hash.new
            dataitem[OMS::Diag::DI_KEY_LOGMESSAGE] = 'Just a test string'
            dataitem[OMS::Diag::DI_KEY_IPNAME] = OMS::Diag::DEFAULT_IPNAME
            dataitem[OMS::Diag::DI_KEY_TIME] = OMS::Diag::GetCurrentFormattedTimeForDiagLogs()
            # Randomly add a few optional properties
            if rand(100) % 2 == 0
                (1..3).each do
                    dataitem[SecureRandom.uuid] = SecureRandom.uuid
                end
            end
            dataitems << dataitem
        end
        # Calling to process the dataitems
        OMS::Diag.ProcessDataItemsPostAggregation(dataitems, agent_id)

        # Verifying the dataitems were processed right
        for x in dataitems
            # Check if IPName is absent
            assert_equal(false,
                         x.key?(OMS::Diag::DI_KEY_IPNAME),
                         "#{OMS::Diag::DI_KEY_IPNAME} should be deleted from dataitem")
            # Check if Agent guid is present
            assert_equal(true,
                         x.key?(OMS::Diag::DI_KEY_AGENTGUID),
                         "#{OMS::Diag::DI_KEY_AGENTGUID} should be added to dataitem")
            # Check if data item type is present
            assert_equal(true,
                         x.key?(OMS::Diag::DI_KEY_TYPE),
                         "#{OMS::Diag::DI_KEY_TYPE} should be added to dataitem")
        end
    end

    # Checking if spurious dataitems are removed by ProcessDataItemsPostAggregation
    def test_case_dataitem_proc_02
        agent_id = 'test-agent-id-1234'
        # Creating valid dataitems
        dataitems = Array.new
        for y in 1..5 do
            dataitem = Hash.new
            dataitem[OMS::Diag::DI_KEY_LOGMESSAGE] = 'Just a test string'
            dataitem[OMS::Diag::DI_KEY_IPNAME] = OMS::Diag::DEFAULT_IPNAME
            dataitem[OMS::Diag::DI_KEY_TIME] = OMS::Diag::GetCurrentFormattedTimeForDiagLogs()
            # Create few spurious cases
            if y == 1
                dataitem.delete(OMS::Diag::DI_KEY_LOGMESSAGE)
            elsif y == 3
                # note this is valid spurious here but without ipname
                # write call of out_oms_diag will set it to default
                dataitem.delete(OMS::Diag::DI_KEY_IPNAME)
            elsif y == 5
                dataitem.delete(OMS::Diag::DI_KEY_TIME)
            end

            dataitems << dataitem
        end

        assert_equal(5, dataitems.size,
                    "There should be 5 dataitems that are considered for this test case")

        # Calling to process the dataitems
        OMS::Diag.ProcessDataItemsPostAggregation(dataitems, agent_id)

        assert_equal(2, dataitems.size,
                    "There should be 2 dataitems that are valid and left after processing")

        # Verifying the valid dataitems were processed right
        for x in dataitems
            # Check if IPName is absent
            assert_equal(false,
                         x.key?(OMS::Diag::DI_KEY_IPNAME),
                         "#{OMS::Diag::DI_KEY_IPNAME} should be deleted from dataitem")
            # Check if Agent guid is present
            assert_equal(true,
                         x.key?(OMS::Diag::DI_KEY_AGENTGUID),
                         "#{OMS::Diag::DI_KEY_AGENTGUID} should be added to dataitem")
            # Check if data item type is present
            assert_equal(true,
                         x.key?(OMS::Diag::DI_KEY_TYPE),
                         "#{OMS::Diag::DI_KEY_TYPE} should be added to dataitem")
        end
    end

    # Test cases pertaining to record creation

    # Checking if spurious properties do not override mandatory ones
    def test_case_record_proc_01
        agent_id = 'test-agent-id-1234'
        # Creating valid dataitems
        dataitems = Array.new
        (1..5).each do
            dataitem = Hash.new
            dataitem[OMS::Diag::DI_KEY_LOGMESSAGE] = 'Just a test string'
            dataitem[OMS::Diag::DI_KEY_IPNAME] = OMS::Diag::DEFAULT_IPNAME
            dataitem[OMS::Diag::DI_KEY_TIME] = OMS::Diag::GetCurrentFormattedTimeForDiagLogs()
            dataitems << dataitem
        end

        # Calling to process the dataitems
        OMS::Diag.ProcessDataItemsPostAggregation(dataitems, agent_id)

        # Now creating the spurious optionalAttributes hash
        optionalAttributes = Hash.new
        optionalAttributes[OMS::Diag::RECORD_DATAITEMS] = nil
        optionalAttributes[OMS::Diag::RECORD_IPNAME] = 'Spurious IPName'
        optionalAttributes[OMS::Diag::RECORD_MGID] = 'Spurious MGID'

        # Now call create diag record
        testIPName = 'test-ipname'
        record = OMS::Diag.CreateDiagRecord(dataitems, testIPName, optionalAttributes)

        # Now check the mandatory keys of record
        assert_equal(true,
                     record.key?(OMS::Diag::RECORD_DATAITEMS),
                     "#{OMS::Diag::RECORD_DATAITEMS} key should be present in record")
        assert_equal(true,
                     record[OMS::Diag::RECORD_DATAITEMS].is_a?(Array),
                     "#{OMS::Diag::RECORD_DATAITEMS} key should be an array")
        assert_equal(true,
                     record.key?(OMS::Diag::RECORD_IPNAME),
                     "#{OMS::Diag::RECORD_IPNAME} key should be present in record")
        assert_equal(testIPName,
                     record[OMS::Diag::RECORD_IPNAME],
                     "#{OMS::Diag::RECORD_IPNAME} key should be equal to #{testIPName}")
        assert_equal(true,
                     record.key?(OMS::Diag::RECORD_MGID),
                     "#{OMS::Diag::RECORD_MGID} key should be present in record")
        assert_equal(OMS::Diag::RECORD_MGID_VALUE,
                     record[OMS::Diag::RECORD_MGID],
                     "#{OMS::Diag::RECORD_MGID} key should be equal to #{OMS::Diag::RECORD_MGID_VALUE}")
    end

    # Test cases pertaining to version check

    # Checking diagnostic support with lower omsagent version
    def test_case_version_check_01
        versions = ["1.3.4-126", "1.3.3-127", "1.2.4-127", "0.3.4-127", "1.2.2-123", "1.0.4-1"]

        versions.each do |v|
            # Setting up version file
            File.open(OMS::Diag.GetInstallInfoPath(), 'w') do |file|
                file.puts "#{v} xcwer23234 Release_Build"
            end

            # Forcing parsing of version file
            OMS::Diag.SetDiagSupported(nil)

            # Checking the diag is not enabled
            assert_equal(false,
                     OMS::Diag.IsDiagSupported(),
                     "Diagnostic logging should not be supported for lower version #{v} than min version")
        end
    end

    # Checking diagnostic support with min omsagent version
    def test_case_version_check_02
        # Setting up version file
        File.open(OMS::Diag.GetInstallInfoPath(), 'w') do |file|
            file.puts "#{OMS::Diag::DIAG_MIN_VERSION} xcwer23234 Release_Build"
        end

        # Forcing parsing of version file
        OMS::Diag.SetDiagSupported(nil)

        # Checking that diag is enabled
        assert_equal(true,
                     OMS::Diag.IsDiagSupported(),
                     "Diagnostic logging should be supported for when version is min version")
    end

    # Checking diagnostic support with higher omsagent version
    def test_case_version_check_03
        versions = ["1.3.4-128", "1.3.5-127", "1.4.4-127", "2.3.4-127", "1.4.0-1", "1.3.5-0", "1.3.12-4"]

        versions.each do |v|
            # Setting up version file
            File.open(OMS::Diag.GetInstallInfoPath(), 'w') do |file|
                file.puts "#{v} xcwer23234 Release_Build"
            end

            # Forcing parsing of version file
            OMS::Diag.SetDiagSupported(nil)

            # Checking that diag is enabled
            assert_equal(true,
                     OMS::Diag.IsDiagSupported(),
                     "Diagnostic logging should be supported for higher version #{v} than min version")
        end
    end

    # Checking diagnostic support with invalid omsagent version string
    def test_case_version_check_04
        versions = ["1.3.4", "1.3-127", "1-127", "1.3.4-a127", "1.2.3.4-127"]

        versions.each do |v|
            # Setting up version file
            File.open(OMS::Diag.GetInstallInfoPath(), 'w') do |file|
                file.puts "#{v} xcwer23234 Release_Build"
            end

            # Forcing parsing of version file
            OMS::Diag.SetDiagSupported(nil)

            # Checking the diag is not enabled
            assert_equal(false,
                     OMS::Diag.IsDiagSupported(),
                     "Diagnostic logging should not be supported for invalid version string #{v}")
        end
    end

    # Checking diagnostic support with invalid file path
    def test_case_version_check_05
        # Remove any version file if existant
        File.unlink(OMS::Diag.GetInstallInfoPath()) if File.exist?(OMS::Diag.GetInstallInfoPath())

        # Forcing parsing of version file
        OMS::Diag.SetDiagSupported(nil)

        # Checking the diag is not enabled
        assert_equal(false,
                 OMS::Diag.IsDiagSupported(),
                 "Diagnostic logging should not be supported as install info file does not exist")
    end
end
