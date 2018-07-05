require 'test/unit'
require_relative 'omstestlib'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/auditd_plugin_lib'

class AuditdPluginLibTest < Test::Unit::TestCase
    class << self
        def startup
        @@auditd_plugin = OMS::AuditdPlugin.new(OMS::MockLog.new)
        end

        def shutdown
        #no op
        end
    end

    def test_nil_event
        audit_blob = @@auditd_plugin.transform_and_wrap(nil, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
    end

    def test_missing_records_event
        record = {}

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
    end

    def test_invalid_records_event
        record = {
            "records" => nil
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")

        record = {
            "records" => "bad"
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")

        record = {
            "records" => []
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
    end

    def test_missing_timestamp_event
        record = {
            "SerialNumber" => 731250,
            "records" => [{"Field1"=>"Value1"}]
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
    end

    def test_missing_serial_number_event
        record = {
            "Timestamp" => "1485983836.377",
            "records" => [{"Field1"=>"Value1"}]
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
    end

    def test_invalid_record_data_event
        [nil,"str",23,23.5,[1,2,3],{}].each do |json|
            record = {
                "Timestamp" => "1485983836.377",
                "SerialNumber" => 731250,
                "records" => [json]
            }

            audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

            assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
        end
    end

    def test_one_record_event
        record = {
            "Timestamp" => "1485983836.377",
            "SerialNumber" => 731250,
            "records" => [{"Field1" => "Value1"}]
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(!audit_blob.nil?, "Returned value is unexpectedly nil!")
        assert_equal("LINUX_AUDITD_BLOB", audit_blob["DataType"], "Invalid 'DataType' value")
        assert_equal("Security", audit_blob["IPName"], "Invalid 'IPName' value")
        assert_equal(1, audit_blob["DataItems"].length, "Invalid number of DataItems")
        assert_equal("1485983836.377:731250", audit_blob["DataItems"][0]["AuditID"], "Invalid AuditID in DataItem")
        assert_equal("2017-02-01T21:17:16.377Z", audit_blob["DataItems"][0]["Timestamp"], "Invalid Timestamp in DataItem")
        assert_equal(731250, audit_blob["DataItems"][0]["SerialNumber"], "Invalid SerialNumber in DataItem")
        assert_equal("Value1", audit_blob["DataItems"][0]["Field1"], "Invalid Field value DataItem")
    end

    def test_multi_record_event
        record = {
            "Timestamp" => "1485983836.377",
            "SerialNumber" => 731250,
            "records" => [{"Field1" => "Value1"},{"Field1" => "Value2"}]
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(!audit_blob.nil?, "Returned value is unexpectedly nil!")
        assert_equal("LINUX_AUDITD_BLOB", audit_blob["DataType"], "Invalid 'DataType' value")
        assert_equal("Security", audit_blob["IPName"], "Invalid 'IPName' value")
        assert_equal(2, audit_blob["DataItems"].length, "Invalid number of DataItems")

        assert_equal("1485983836.377:731250", audit_blob["DataItems"][0]["AuditID"], "Invalid AuditID in DataItem")
        assert_equal("2017-02-01T21:17:16.377Z", audit_blob["DataItems"][0]["Timestamp"], "Invalid Timestamp in DataItem")
        assert_equal(731250, audit_blob["DataItems"][0]["SerialNumber"], "Invalid SerialNumber in DataItem")
        assert_equal("Value1", audit_blob["DataItems"][0]["Field1"], "Invalid Field value DataItem")

        assert_equal("1485983836.377:731250", audit_blob["DataItems"][1]["AuditID"], "Invalid AuditID in DataItem")
        assert_equal("2017-02-01T21:17:16.377Z", audit_blob["DataItems"][1]["Timestamp"], "Invalid Timestamp in DataItem")
        assert_equal(731250, audit_blob["DataItems"][1]["SerialNumber"], "Invalid SerialNumber in DataItem")
        assert_equal("Value2", audit_blob["DataItems"][1]["Field1"], "Invalid Field value DataItem")
    end
end
