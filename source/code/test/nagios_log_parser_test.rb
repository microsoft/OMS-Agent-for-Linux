# Copyright (c) Microsoft Corporation.  All rights reserved.
require 'test/unit'
require_relative '../plugins/nagios_parser_lib'
		
class TestRuntimeError < NagiosModule::LoggingBase
	def log_error(text)
		raise text
	end
end

class NagiosLib_Test < Test::Unit::TestCase
	class << self
		def startup
			@@nagios_lib = NagiosModule::Nagios.new(TestRuntimeError.new)
		end

		def shutdown
			#no op
		end
	end

	def test_parse_null_empty_record_returns_empty
		assert_equal({}, call_parse_alert(nil), "null record fails")
		assert_equal({}, call_parse_alert(""), "empty record record fails")
	end

	def test_parse_non_alerts_returns_empty
		assert_equal({}, call_parse_alert("[1436810470] notification: nagios-5;down;soft;1;critical - host unreachable (10.185.208.113)"), "non alert record fails")
	end  

	def test_parse_invalid_alerts_returns_empty
		exception = assert_raise(RuntimeError) {call_parse_alert("HOST ALERT;bbb;ccc")}
		assert_equal(exception.message, "Alert Array Length invalid: should contain 5 or 6 sections", "Expected Invalid Exception")

		exception = assert_raise(RuntimeError) {call_parse_alert("SERVICE ALERT;bbb;ccc;ddd;eeeee;fff;ggg")}
		assert_equal(exception.message, "Alert Array Length invalid: should contain 5 or 6 sections", "Expected Invalid Exception")

		exception = assert_raise(RuntimeError) {call_parse_alert("[1436810470] : HOST ALERT: nagios-5;a;b;c;d")}
		assert_equal(exception.message, "timestamp and alert host must be in 2 sections", "Expected Invalid Exception")

		exception = assert_raise(RuntimeError) {call_parse_alert("[1436810470] extra space      HOST ALERT: nagios-5;a;b;c;d")}
		assert_equal(exception.message, "unrecognized alert name", "Expected Invalid Exception")
	end	

	def test_parse_valid_alerts_returns_valid_records
		#valid host alert record
		expected_record = {
			"Timestamp"=>"2015-07-13T18:01:10+00:00",
			"AlertName"=>"HOST ALERT",
			"HostName"=>"nagios-5",
			"State"=>"DOWN",
			"StateType"=>"SOFT",
			"AlertPriority"=>1,
			"AlertDescription"=>"CRITICAL - Host Unreachable (10.185.208.113)"
		}
		host_alert_record = call_parse_alert("[1436810470] HOST ALERT: nagios-5;DOWN;SOFT;1;CRITICAL - Host Unreachable (10.185.208.113)")
		validate_record_helper(expected_record, host_alert_record)

		#valid service record
		expected_record = {
			"Timestamp"=>"2015-07-13T18:01:30+00:00",
			"AlertName"=>"SERVICE ALERT",
			"HostName"=>"nagios-2",
			"State"=>"CRITICAL",
			"StateType"=>"SOFT",
			"AlertPriority"=>1,
			"AlertDescription"=>"CHECK_NRPE: Error - Could not complete SSL handshake."
		}
		host_alert_record = call_parse_alert("[1436810490] SERVICE ALERT: nagios-2;Current Users;CRITICAL;SOFT;1;CHECK_NRPE: Error - Could not complete SSL handshake.")
		validate_record_helper(expected_record, host_alert_record)

		#valid host record invalid timestamp defaulted timestamp, blank spaces
		expected_record = {
			"Timestamp"=>"1970-01-01T00:00:00+00:00",
			"AlertName"=>"SERVICE ALERT",
			"HostName"=>"host100",
			"State"=>"alert state",
			"StateType"=>"state type",
			"AlertPriority"=>0,
			"AlertDescription"=>"Alert Description."
		}
		host_alert_record = call_parse_alert("[invalidtime] SERVICE ALERT: host100;alert misc;alert state;state type;0  ;Alert Description.")
		validate_record_helper(expected_record, host_alert_record)
	end 

	# helper method to validate record  
	#
	def validate_record_helper(expected, actual)
		assert_equal(expected["Timestamp"], actual["Timestamp"], "Timestamp doesn't match")
		assert_equal(expected["AlertName"], actual["AlertName"], "AlertName doesn't match")
		assert_equal(expected["HostName"], actual["HostName"], "HostName doesn't match")
		assert_equal(expected["State"], actual["State"], "State doesn't match")
		assert_equal(expected["StateType"], actual["StateType"], "StateType doesn't match")
		assert_equal(expected["AlertPriority"], actual["AlertPriority"], "AlertPriority doesn't match")
		assert_equal(expected["AlertDescription"], actual["AlertDescription"], "AlertDescription doesn't match") 
		assert_equal(7, actual.length, "Alert Record invalid number of elements")
	end

	# wrapper to call parse alert record
	#
	def call_parse_alert(text)
		@@nagios_lib.parse_alert_record(text)
  end  
end