require 'fluent/test'
require_relative ENV['BASE_DIR'] + '/source/ext/fluentd/test/helper'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/out_oms'
require_relative 'omstestlib'

class OutOMSTest < Test::Unit::TestCase

  # These keys should be loaded in environment variables
  TEST_WORKSPACE_ID=ENV['TEST_WORKSPACE_ID']
  TEST_SHARED_KEY=ENV['TEST_SHARED_KEY']

  def setup
    Fluent::Test.setup
    
    @base_dir = ENV['BASE_DIR']
    @ruby_test_dir = ENV['RUBY_TESTING_DIR']
    @prep_omsadmin = "#{ENV['BASE_DIR']}/test/installer/scripts/prep_omsadmin.sh"

    $log = OMS::MockLog.new
  end

  def teardown
    if @omsadmin_test_dir and File.directory? @omsadmin_test_dir
      FileUtils.rm_r @omsadmin_test_dir
      assert_equal(false, File.directory?(@omsadmin_test_dir))
    end
  end

  def prep_onboard
    # Setup test onboarding script and folder
    @omsadmin_test_dir = `#{@prep_omsadmin} #{@base_dir} #{@ruby_test_dir}`.strip()
    assert_equal(0, $?.to_i, "Unexpected failure setting up the test")
  end
  
  def do_onboard
    omsadmin_script = "#{@omsadmin_test_dir}/omsadmin.sh"
    onboard_out = `#{omsadmin_script} -w #{TEST_WORKSPACE_ID} -s #{TEST_SHARED_KEY}`
    assert_equal(0, $?.to_i, "Unexpected failure onboarding : '#{onboard_out}'")
  end

  def test_send_data
    # Make sure that we read test onboarding information from the environment varibles
    assert(TEST_WORKSPACE_ID != nil, "TEST_WORKSPACE_ID should be set by the environment for this test to run.") 
    assert(TEST_SHARED_KEY != nil, "TEST_SHARED_KEY should be set by the environment for this test to run.")

    assert(TEST_WORKSPACE_ID.empty? == false, "TEST_WORKSPACE_ID should not be empty.") 
    assert(TEST_SHARED_KEY.empty? == false, "TEST_SHARED_KEY should not be empty.")

    # Onboard to create cert and key
    prep_onboard
    do_onboard
    
    # Mock the configuration
    conf = %[
      omsadmin_conf_path #{@omsadmin_test_dir}/omsadmin.conf
      cert_path #{@omsadmin_test_dir}/oms.crt
      key_path #{@omsadmin_test_dir}/oms.key
    ]
    tag = 'test'
    d = Fluent::Test::OutputTestDriver.new(Fluent::OutputOMS, tag).configure(conf)
    output = d.instance
    output.start

    # Load endpoint from omsadmin_conf_path
    assert(output.load_endpoint, "Error loading endpoint : '#{$log.logs}'")
    # Load certs, there should not be permissions issues if they are owned by the current user
    assert(output.load_certs, "Error loading certs : '#{$log.logs}'")

    # Mock syslog data
    record = {"DataType"=>"LINUX_SYSLOGS_BLOB", "IPName"=>"logmanagement", "DataItems"=>[{"ident"=>"niroy", "Timestamp"=>"2015-10-26T05:11:22Z", "Host"=>"niroy64-cent7x-01", "HostIP"=>"fe80::215:5dff:fe81:4c2f%eth0", "Facility"=>"local0", "Severity"=>"warn", "Message"=>"Hello"}]}
    assert_nothing_raised(RuntimeError, "Failed to send syslog data : '#{$log.logs}'") do
      output.handle_record("oms.syslog.local0.warn", record)
    end

    # Mock perf data
    $log.clear
    record = {"DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement", "DataItems"=>[{"Timestamp"=>"2015-10-26T05:40:37Z", "Host"=>"niroy64-cent7x-01", "ObjectName"=>"Memory", "InstanceName"=>"Memory", "Collections"=>[{"CounterName"=>"Available MBytes Memory", "Value"=>"564"}, {"CounterName"=>"% Available Memory", "Value"=>"28"}, {"CounterName"=>"Used Memory MBytes", "Value"=>"1417"}, {"CounterName"=>"% Used Memory", "Value"=>"72"}, {"CounterName"=>"Pages/sec", "Value"=>"3"}, {"CounterName"=>"Page Reads/sec", "Value"=>"1"}, {"CounterName"=>"Page Writes/sec", "Value"=>"2"}, {"CounterName"=>"Available MBytes Swap", "Value"=>"1931"}, {"CounterName"=>"% Available Swap Space", "Value"=>"94"}, {"CounterName"=>"Used MBytes Swap Space", "Value"=>"116"}, {"CounterName"=>"% Used Swap Space", "Value"=>"6"}]}]}
    assert(output.handle_record("oms.omi", record), "Failed to send perf data : '#{$log.logs}'")

    # Mock zabbix data
    $log.clear
    record =  {"DataType"=>"LINUX_ZABBIXALERTS_BLOB", "IPName"=>"AlertManagement", "DataItems"=>[{"triggerid": "13498","expression": "{13252}>0","description": "Disk I/O is overloaded on Zabbix server","url": "","status": "0","value": "1","priority": "2","lastchange": "1444934001","comments": "OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.","error": "","templateid": "13243","type": "0","state": "0","flags": "0","hostname": "Zabbix server","host": "Zabbix server","hostid": "10084","value_flags": "0"}, {"triggerid": "13595","expression": "{13198}=1","description": "Zabbix agent on zabbix-client-3 is unreachable for 5 minutes","url": "","status": "0","value": "1","priority": "3","lastchange": "1442391060","comments": "","error": "","templateid": "10047","type": "0","state": "0","flags": "0","hostname": "zabbix-client-3","host": "zabbix-client-3","hostid": "10107","value_flags": "0"}]}
    assert(output.handle_record("oms.zabbix", record), "Failed to send zabbix data : '#{$log.logs}'")

    # Mock Nagios data
    $log.clear
    record = {"DataType"=>"LINUX_NAGIOSALERTS_BLOB", "IPName"=>"AlertManagement", "DataItems"=>[{"Timestamp"=>"1970-01-01T00:00:00+00:00", "AlertName"=>"SERVICE ALERT", "HostName"=>"host100", "State"=>"alert state", "StateType"=>"state type", "AlertPriority"=>0, "AlertDescription"=>"Alert Description."}]} 
    assert(output.handle_record("oms.nagios", record), "Failed to send nagios data : '#{$log.logs}'")
  end

end
