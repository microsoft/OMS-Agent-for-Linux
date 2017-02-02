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
    
    def test_missing_record_count_event
        record = {}

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
    end
    
    def test_invalid_record_count_event
        record = {
            "record-count" => -1
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")

        record = {
            "record-count" => 0
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
    end
    
    def test_missing_record_data_event
        record = {
            "record-count" => 1
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
    end
    
    def test_missing_timestamp_event
        record = {
            "record-count" => 1,
            "SerialNumber" => 731250,
            "record-data-0" => '{"Field1":"Value1"}'
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
    end
    
    def test_missing_serial_number_event
        record = {
            "record-count" => 1,
            "Timestamp" => "1485983836.377",
            "record-data-0" => '{"Field1":"Value1"}'
        }

        audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

        assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
    end
    
    def test_invalid_record_data_event
        ['null','"str"','23','23.5','[1,2,3]','{}'].each do |json|
            record = {
                "record-count" => 1,
                "Timestamp" => "1485983836.377",
                "SerialNumber" => 731250,
                "record-data-0" => json
            }

            audit_blob = @@auditd_plugin.transform_and_wrap(record, "test", nil)

            assert(audit_blob.nil?, "Returned value is unexpectedly NOT nil!")
        end
    end
    
    def test_one_record_event
        record = {
            "record-count" => 1,
            "Timestamp" => "1485983836.377",
            "SerialNumber" => 731250,
            "record-data-0" => '{"Field1":"Value1"}'
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
            "record-count" => 2,
            "Timestamp" => "1485983836.377",
            "SerialNumber" => 731250,
            "record-data-0" => '{"Field1":"Value1"}',
            "record-data-1" => '{"Field1":"Value2"}'
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
