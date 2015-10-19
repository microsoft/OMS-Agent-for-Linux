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

class ZabbixLib_Test < Test::Unit::TestCase
	def test_get_zabbix_alerts_after_watermark
		# One Trigger after watermark date
		one_trigger = [{"triggerid":"13595","expression":"{13198}=1","description":"Zabbix agent on {HOST.NAME} is unreachable for 5 minutes","url":"","status":"0","value":"1","priority":"3","lastchange":"1442391060","comments":"","error":"","templateid":"10047","type":"0","state":"0","flags":"0","hostname":"zabbix-client-3","host":"zabbix-client-3","hostid":"10107","value_flags":"0"}]
		date = "2000-10-01 10:30:14" # Watermark date before triggers
		expected_alert = [{"triggerid": "13595","expression": "{13198}=1","description": "Zabbix agent on zabbix-client-3 is unreachable for 5 minutes","url": "","status": "0","value": "1","priority": "3","lastchange": "1442391060","comments": "","error": "","templateid": "10047","type": "0","state": "0","flags": "0","hostname": "zabbix-client-3","host": "zabbix-client-3","hostid": "10107","value_flags": "0"}]
		get_zabbix_alerts_watermark_helper(one_trigger, expected_alert, date, "Alert after watermark fails")
	end

	def test_get_zabbix_alerts_between_watermark
		# One Alert generated with Two triggers returned in between the watermark date
		two_triggers = [{"triggerid"=>"13498", "expression"=>"{13252}>0", "description"=>"Disk I/O is overloaded on {HOST.NAME}", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"2", "lastchange"=>"1444934001", "comments"=>"OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.", "error"=>"", "templateid"=>"13243", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"Zabbix server", "host"=>"Zabbix server", "hostid"=>"10084", "value_flags"=>"0"}, {"triggerid"=>"13595", "expression"=>"{13198}=1", "description"=>"Zabbix agent on {HOST.NAME} is unreachable for 5 minutes", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"3", "lastchange"=>"1442391060", "comments"=>"", "error"=>"", "templateid"=>"10047", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"zabbix-client-3", "host"=>"zabbix-client-3", "hostid"=>"10107", "value_flags"=>"0"}]
		date = "2015-10-01 10:30:14" # Watermark date in between the triggers
		expected_alerts = [{"triggerid": "13498","expression": "{13252}>0","description": "Disk I/O is overloaded on Zabbix server","url": "","status": "0","value": "1","priority": "2","lastchange": "1444934001","comments": "OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.","error": "","templateid": "13243","type": "0","state": "0","flags": "0","hostname": "Zabbix server","host": "Zabbix server","hostid": "10084","value_flags": "0"}]
		get_zabbix_alerts_watermark_helper(two_triggers, expected_alerts, date, "Alert between watermark fails")
	end

	def test_get_zabbix_alerts_before_watermark
		# One Trigger before watermark date
		two_triggers = [{"triggerid"=>"13498", "expression"=>"{13252}>0", "description"=>"Disk I/O is overloaded on {HOST.NAME}", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"2", "lastchange"=>"1444934001", "comments"=>"OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.", "error"=>"", "templateid"=>"13243", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"Zabbix server", "host"=>"Zabbix server", "hostid"=>"10084", "value_flags"=>"0"}, {"triggerid"=>"13595", "expression"=>"{13198}=1", "description"=>"Zabbix agent on {HOST.NAME} is unreachable for 5 minutes", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"3", "lastchange"=>"1442391060", "comments"=>"", "error"=>"", "templateid"=>"10047", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"zabbix-client-3", "host"=>"zabbix-client-3", "hostid"=>"10107", "value_flags"=>"0"}]
		date = "2020-10-01 10:30:14" # Watermark after triggers
		expected_alerts = []
		get_zabbix_alerts_watermark_helper(two_triggers, expected_alerts, date, "Alert before watermark fails")
	end

	def test_get_duplicate_zabbix_alerts
		# The same trigger returned in repeated calls should not send duplicate alerts
		two_triggers = [{"triggerid"=>"13498", "expression"=>"{13252}>0", "description"=>"Disk I/O is overloaded on {HOST.NAME}", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"2", "lastchange"=>"1444934001", "comments"=>"OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.", "error"=>"", "templateid"=>"13243", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"Zabbix server", "host"=>"Zabbix server", "hostid"=>"10084", "value_flags"=>"0"}, {"triggerid"=>"13595", "expression"=>"{13198}=1", "description"=>"Zabbix agent on {HOST.NAME} is unreachable for 5 minutes", "url"=>"", "status"=>"0", "value"=>"1", "priority"=>"3", "lastchange"=>"1442391060", "comments"=>"", "error"=>"", "templateid"=>"10047", "type"=>"0", "state"=>"0", "flags"=>"0", "hostname"=>"zabbix-client-3", "host"=>"zabbix-client-3", "hostid"=>"10107", "value_flags"=>"0"}]
		date = "2000-10-01 10:30:14"
		expected_alerts_1 = [{"triggerid": "13498","expression": "{13252}>0","description": "Disk I/O is overloaded on Zabbix server","url": "","status": "0","value": "1","priority": "2","lastchange": "1444934001","comments": "OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.","error": "","templateid": "13243","type": "0","state": "0","flags": "0","hostname": "Zabbix server","host": "Zabbix server","hostid": "10084","value_flags": "0"}, {"triggerid": "13595","expression": "{13198}=1","description": "Zabbix agent on zabbix-client-3 is unreachable for 5 minutes","url": "","status": "0","value": "1","priority": "3","lastchange": "1442391060","comments": "","error": "","templateid": "10047","type": "0","state": "0","flags": "0","hostname": "zabbix-client-3","host": "zabbix-client-3","hostid": "10107","value_flags": "0"}]
		expected_alerts_2 = []

		@mock_query = ZabbixApiQuery_Test.new
		
		@mock_query.set_query_returns(two_triggers)
		@mock_zabbix_client = ZabbixApiWrapper_Test.new(@mock_query)
		
		@zabbix_lib = ZabbixModule::Zabbix.new(TestRuntimeError3.new, DateTime.parse(date).to_time.to_i, @mock_zabbix_client, "Zabbix Server Url", "Zabbix Username", "Zabbix Password")
		
		assert_equal(expected_alerts_1.to_json, @zabbix_lib.get_alert_records.to_json, "Alert after watermark fails")
		assert_equal(expected_alerts_2.to_json, @zabbix_lib.get_alert_records.to_json, "Watermark failed to update")
	end
	
	def get_zabbix_alerts_watermark_helper(mock_triggers_returned, expected_alerts, watermark_date, failure_message)
		@mock_query = ZabbixApiQuery_Test.new
		
		@mock_query.set_query_returns(mock_triggers_returned)
		@mock_zabbix_client = ZabbixApiWrapper_Test.new(@mock_query)
		
		@zabbix_lib = ZabbixModule::Zabbix.new(TestRuntimeError3.new, DateTime.parse(watermark_date).to_time.to_i, @mock_zabbix_client, "Zabbix Server Url", "Zabbix Username", "Zabbix Password")
		
		assert_equal(expected_alerts.to_json, @zabbix_lib.get_alert_records.to_json, failure_message)
	end

end