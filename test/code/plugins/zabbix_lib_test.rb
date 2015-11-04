require 'test/unit'
require 'date'
require_relative '../../../source/code/plugins/zabbix_lib'
		
class TestRuntimeError3 < ZabbixModule::LoggingBase
	def log_error(text)
		raise text
	end
end

class ZabbixApiWrapper_Test
	def initialize(query_stub)
		@query_stub = query_stub
	end
	
	def connect(options = {})
		return @query_stub
	end
end

class ZabbixApiQuery_Test
	def set_query_returns(data)
		@return_query = data
	end
	
	def query(data)
		return @return_query
	end
end

class ZabbixClient_Test
	attr_writer :version
	
	def initialize(options={})
		#no op
	end
	
	def api_version
		return @version
	end
end

class ZabbixLib_Test < Test::Unit::TestCase
	class << self
		def startup
			@@watermark_test_file = "zabbix_test_watermark"
		end

		def shutdown
			#no op
		end
	end

	def setup
		delete_watermark_helper
	end
	
	def teardown
		delete_watermark_helper
	end
	
	def test_zabbix_client_versions
		verify_invalid_client_version("1.8.4")
		verify_invalid_client_version("3.0.2")
		verify_invalid_client_version("2.0")
		verify_invalid_client_version("2.4")
		
		verify_valid_client_version("2.0.15")
		verify_valid_client_version("2.4.6")
		verify_valid_client_version("2.2.12")
	end
	
	def verify_invalid_client_version(version)
		@mock_client = ZabbixClient_Test.new
		@mock_client.version = version
		exception = assert_raise(RuntimeError) {ZabbixApiWrapper.new({}, @mock_client)}
		assert_equal(exception.message, "Zabbix API version: #{version} is not support by this version of zabbixapi", "Expected Invalid Exception")
	end

	def verify_valid_client_version(version)
		@mock_client = ZabbixClient_Test.new
		@mock_client.version = version
		ZabbixApiWrapper.new({}, @mock_client) # no exception thrown means it was the correct client version
	end

	def test_get_zabbix_alerts_after_watermark
		# One Trigger after watermark date
		one_trigger = [{"triggerid":"13595","expression":"{13198}=1","description":"Zabbix agent on {HOST.NAME} is unreachable for 5 minutes","url":"","status":"0","value":"1","priority":"3","lastchange":"1442391060","comments":"","error":"","templateid":"10047","type":"0","state":"0","flags":"0","hostname":"zabbix-client-3","host":"zabbix-client-3","hostid":"10107","value_flags":"0"}]
		date = Date.new(2000, 10, 1).to_time.to_i # Watermark date before triggers
		expected_alert = [{"triggerid": "13595","expression": "{13198}=1","description": "Zabbix agent on zabbix-client-3 is unreachable for 5 minutes","url": "","status": "0","value": "1","priority": "3","lastchange": "1442391060","comments": "","error": "","templateid": "10047","type": "0","state": "0","flags": "0","hostname": "zabbix-client-3","host": "zabbix-client-3","hostid": "10107","value_flags": "0"}]
		get_zabbix_alerts_watermark_helper(one_trigger, expected_alert, date, "Alert after watermark fails")
		
		validate_watermark(1442391060)
	end

	def test_get_zabbix_alerts_between_watermark
		# One Alert generated with Two triggers returned in between the watermark date
		two_triggers = [{"triggerid"=>"13498", "expression"=>"{13252}>0", "description"=>"Disk I/O is overloaded on {HOST.NAME}", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"2", "lastchange"=>"1444934001", "comments"=>"OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.", "error"=>"", "templateid"=>"13243", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"Zabbix server", "host"=>"Zabbix server", "hostid"=>"10084", "value_flags"=>"0"}, {"triggerid"=>"13595", "expression"=>"{13198}=1", "description"=>"Zabbix agent on {HOST.NAME} is unreachable for 5 minutes", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"3", "lastchange"=>"1442391060", "comments"=>"", "error"=>"", "templateid"=>"10047", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"zabbix-client-3", "host"=>"zabbix-client-3", "hostid"=>"10107", "value_flags"=>"0"}]
		date = Date.new(2015, 10, 1).to_time.to_i #"2015-10-01 10:30:14" # Watermark date in between the triggers
		expected_alerts = [{"triggerid": "13498","expression": "{13252}>0","description": "Disk I/O is overloaded on Zabbix server","url": "","status": "0","value": "1","priority": "2","lastchange": "1444934001","comments": "OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.","error": "","templateid": "13243","type": "0","state": "0","flags": "0","hostname": "Zabbix server","host": "Zabbix server","hostid": "10084","value_flags": "0"}]
		get_zabbix_alerts_watermark_helper(two_triggers, expected_alerts, date, "Alert between watermark fails")

		validate_watermark(1444934001)
	end

	def test_get_zabbix_alerts_before_watermark
		# One Trigger before watermark date
		two_triggers = [{"triggerid"=>"13498", "expression"=>"{13252}>0", "description"=>"Disk I/O is overloaded on {HOST.NAME}", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"2", "lastchange"=>"1444934001", "comments"=>"OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.", "error"=>"", "templateid"=>"13243", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"Zabbix server", "host"=>"Zabbix server", "hostid"=>"10084", "value_flags"=>"0"}, {"triggerid"=>"13595", "expression"=>"{13198}=1", "description"=>"Zabbix agent on {HOST.NAME} is unreachable for 5 minutes", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"3", "lastchange"=>"1442391060", "comments"=>"", "error"=>"", "templateid"=>"10047", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"zabbix-client-3", "host"=>"zabbix-client-3", "hostid"=>"10107", "value_flags"=>"0"}]
		date = Date.new(2020, 10, 1).to_time.to_i # Watermark after triggers
		expected_alerts = []
		get_zabbix_alerts_watermark_helper(two_triggers, expected_alerts, date.to_i, "Alert before watermark fails")
		
		validate_watermark(date)
	end

	def test_get_duplicate_zabbix_alerts
		# The same trigger returned in repeated calls should not send duplicate alerts
		two_triggers = [{"triggerid"=>"13498", "expression"=>"{13252}>0", "description"=>"Disk I/O is overloaded on {HOST.NAME}", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"2", "lastchange"=>"1444934001", "comments"=>"OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.", "error"=>"", "templateid"=>"13243", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"Zabbix server", "host"=>"Zabbix server", "hostid"=>"10084", "value_flags"=>"0"}, {"triggerid"=>"13595", "expression"=>"{13198}=1", "description"=>"Zabbix agent on {HOST.NAME} is unreachable for 5 minutes", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"3", "lastchange"=>"1442391060", "comments"=>"", "error"=>"", "templateid"=>"10047", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"zabbix-client-3", "host"=>"zabbix-client-3", "hostid"=>"10107", "value_flags"=>"0"}]
		date = Date.new(2000, 10, 1).to_time.to_i
		expected_alerts_1 = [{"triggerid": "13498","expression": "{13252}>0","description": "Disk I/O is overloaded on Zabbix server","url": "","status": "0","value": "1","priority": "2","lastchange": "1444934001","comments": "OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.","error": "","templateid": "13243","type": "0","state": "0","flags": "0","hostname": "Zabbix server","host": "Zabbix server","hostid": "10084","value_flags": "0"}, {"triggerid": "13595","expression": "{13198}=1","description": "Zabbix agent on zabbix-client-3 is unreachable for 5 minutes","url": "","status": "0","value": "1","priority": "3","lastchange": "1442391060","comments": "","error": "","templateid": "10047","type": "0","state": "0","flags": "0","hostname": "zabbix-client-3","host": "zabbix-client-3","hostid": "10107","value_flags": "0"}]
		expected_alerts_2 = []

		@mock_query = ZabbixApiQuery_Test.new
		
		@mock_query.set_query_returns(two_triggers)
		@mock_zabbix_client = ZabbixApiWrapper_Test.new(@mock_query)
		
		@zabbix_lib = ZabbixModule::Zabbix.new(TestRuntimeError3.new, @@watermark_test_file, date.to_i, @mock_zabbix_client, "Zabbix Server Url", "Zabbix Username", "Zabbix Password")
		
		assert_equal(expected_alerts_1.to_json, @zabbix_lib.get_alert_records.to_json, "Alert after watermark fails")
		validate_watermark(1444934001)
		assert_equal(expected_alerts_2.to_json, @zabbix_lib.get_alert_records.to_json, "Watermark failed to update")
		validate_watermark(1444934001)
	end
	
	def get_zabbix_alerts_watermark_helper(mock_triggers_returned, expected_alerts, watermark_date, failure_message)
		
		@mock_query = ZabbixApiQuery_Test.new
		
		@mock_query.set_query_returns(mock_triggers_returned)
		@mock_zabbix_client = ZabbixApiWrapper_Test.new(@mock_query)
		
		@zabbix_lib = ZabbixModule::Zabbix.new(TestRuntimeError3.new, @@watermark_test_file, watermark_date, @mock_zabbix_client, "Zabbix Server Url", "Zabbix Username", "Zabbix Password")
		
		assert_equal(expected_alerts.to_json, @zabbix_lib.get_alert_records.to_json, failure_message)
		
	end
	
	def validate_watermark(watermark)
		assert_equal(true, File.file?(@@watermark_test_file), "Watermark state file was not created")
		assert_equal(watermark, File.read(@@watermark_test_file).to_i, "Incorrect watermark stored in state file")
	end
	
	def delete_watermark_helper
		# Delete test watermark
		if (File.file?(@@watermark_test_file))
			File.delete(@@watermark_test_file)
		end
	end
end