require 'fluent/test'
require_relative ENV['BASE_DIR'] + '/source/ext/fluentd/test/helper'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/out_oms'
require_relative 'omstestlib'

class OutOMSTest < Test::Unit::TestCase

  Workspace_id="cec9ea66-f775-41cd-a0a6-2d0f0ffdac6f"
  Shared_key="qoTgVB0a1393p4FUncrY0nc/U1/CkOYlXz3ok3Oe79gSB6NLa853hiQzcwcyBb10Rjj7iswRvoJGtLJUD/o/yw=="

  def setup
    Fluent::Test.setup
    
    @base_dir = ENV['BASE_DIR']
    @ruby_test_dir = ENV['RUBY_TESTING_DIR']
    @prep_omsadmin = "#{ENV['BASE_DIR']}/test/installer/scripts/prep_omsadmin.sh"

    # This is a static workspace ID and shared key that should not change
    $log = OMS::MockLog.new
  end

  def teardown
    if @omsadmin_test_dir and File.directory? @omsadmin_test_dir
      FileUtils.rm_r @omsadmin_test_dir
      assert_equal(false, File.directory?(@omsadmin_test_dir))
    end
  end

  def test_onboard
    # Setup test onboarding script and folder
    @omsadmin_test_dir = `#{@prep_omsadmin} #{@base_dir} #{@ruby_test_dir}`.strip()
    result = $?
    assert_equal(0, result.to_i, "Unexpected failure setting up the test")
    assert_equal(true, File.directory?(@omsadmin_test_dir), "'#{@omsadmin_test_dir}' does not exist!")

    # Onboard    
    omsadmin_script = "#{@omsadmin_test_dir}/omsadmin.sh"
    assert_equal(true, File.file?(omsadmin_script), "'#{omsadmin_script}' does not exist!")
    assert_equal(true, File.executable?(omsadmin_script), "'#{omsadmin_script}' is not executable.")
    onboard_out = `sudo #{omsadmin_script} -w #{Workspace_id} -s #{Shared_key}`
    result = $?
    assert_equal(0, result.to_i, "Unexpected failure onboarding : '#{onboard_out}'")

    # Make sure certs and config was generated
    assert(File.file?("#{@omsadmin_test_dir}/oms.crt"), "Cert does not exist!")
    assert(File.file?("#{@omsadmin_test_dir}/oms.key"), "Key does not exist!")
    assert(File.file?("#{@omsadmin_test_dir}/omsadmin.conf"), "Omsadmin.conf does not exist!")

    # Check permissions
    uid_crt = File.stat("#{@omsadmin_test_dir}/oms.crt").uid
    uid_key = File.stat("#{@omsadmin_test_dir}/oms.key").uid
    assert(uid_crt == uid_key, "Key and cert should have the same uid")

    # Fails if omsagent user does not exist    
    # owner = Etc.getpwuid(uid_crt).name
    # assert_equal("omsagent", owner, "Owner should be omsagent for the key and cert")
  end

  def test_send_data
    # Call test_onboard to create cert and key
    test_onboard
    
    # Mock the configuration
    conf = {
      "omsadmin_conf_path" => "#{@omsadmin_test_dir}/omsadmin.conf",
      "cert_path" => "#{@omsadmin_test_dir}/oms.crt",
      "key_path" => "#{@omsadmin_test_dir}/oms.key"
    }

    output = Fluent::OutputOMS.new
    output.configure conf
    output.start

    # Load endpoint from omsadmin_conf_path
    assert(output.load_endpoint, "Error loading endpoint : '#{$log.logs}'")
    
    # Chown the cert and key so that we can load them with this process
    uid = Process.uid
    pwd = Etc.getpwuid(uid)
    gid = pwd.gid
    out = `sudo chown -R #{uid}:#{gid} #{@omsadmin_test_dir}`
    result = $?
    assert_equal("", out, "Did not expect output of chown command : '#{out}'")
    assert_equal(0, result, "Chown returned error code : '#{result}'")

    assert(output.load_certs, "Error loading certs : '#{$log.logs}'")

    # Mock syslog data
    record = {"DataType"=>"LINUX_SYSLOGS_BLOB", "IPName"=>"logmanagement", "DataItems"=>[{"ident"=>"niroy", "Timestamp"=>"2015-10-26T05:11:22Z", "Host"=>"niroy64-cent7x-01", "HostIP"=>"fe80::215:5dff:fe81:4c2f%eth0", "Facility"=>"local0", "Severity"=>"warn", "Message"=>"Hello"}]}
    assert(output.handle_record("oms.syslog.local0.warn", record), "Failed to send syslog data")
    assert_equal(["Success sending oms.syslog.local0.warn"], $log.logs, "Did not log the expected sucess message")

    $log.clear
    
    # Mock perf data
    record = {"DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement", "DataItems"=>[{"Timestamp"=>"2015-10-26T05:40:37Z", "Host"=>"niroy64-cent7x-01", "ObjectName"=>"Memory", "InstanceName"=>"Memory", "Collections"=>[{"CounterName"=>"Available MBytes Memory", "Value"=>"564"}, {"CounterName"=>"% Available Memory", "Value"=>"28"}, {"CounterName"=>"Used Memory MBytes", "Value"=>"1417"}, {"CounterName"=>"% Used Memory", "Value"=>"72"}, {"CounterName"=>"Pages/sec", "Value"=>"3"}, {"CounterName"=>"Page Reads/sec", "Value"=>"1"}, {"CounterName"=>"Page Writes/sec", "Value"=>"2"}, {"CounterName"=>"Available MBytes Swap", "Value"=>"1931"}, {"CounterName"=>"% Available Swap Space", "Value"=>"94"}, {"CounterName"=>"Used MBytes Swap Space", "Value"=>"116"}, {"CounterName"=>"% Used Swap Space", "Value"=>"6"}]}]}
    assert(output.handle_record("oms.omi", record), "Failed to send perf data")
    assert_equal(["Success sending oms.omi"], $log.logs, "Did not log the expected sucess message")
    
  end
  

end
