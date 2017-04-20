require 'test/unit'
require 'fluent/test'
require 'securerandom'
require_relative 'in_diag_tester'
require_relative '../../../source/code/plugins/oms_diag'

class OMSDiagUT < Test::Unit::TestCase

    def setup
        Fluent::Test.setup
    end

    def teardown
        super
        Fluent::Engine.stop
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
            dataitem[OMS::Diag::DI_KEY_TIME] = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%6NZ")
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
            dataitem[OMS::Diag::DI_KEY_TIME] = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%6NZ")
            # Create few spurious cases
            if y == 1
                dataitem.delete(OMS::Diag::DI_KEY_LOGMESSAGE)
            elsif y == 3
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
            dataitem[OMS::Diag::DI_KEY_TIME] = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%6NZ")
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

end
