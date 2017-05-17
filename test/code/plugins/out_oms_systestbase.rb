require 'fluent/test'
require_relative ENV['BASE_DIR'] + '/source/ext/fluentd/test/helper'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/oms_configuration'
require_relative 'omstestlib'

class OutOMSSystemTestBase < Test::Unit::TestCase

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
    # Make sure that we read test onboarding information from the environment varibles
    assert(TEST_WORKSPACE_ID != nil, "TEST_WORKSPACE_ID should be set by the environment for this test to run.")
    assert(TEST_SHARED_KEY != nil, "TEST_SHARED_KEY should be set by the environment for this test to run.")

    assert(TEST_WORKSPACE_ID.empty? == false, "TEST_WORKSPACE_ID should not be empty.")
    assert(TEST_SHARED_KEY.empty? == false, "TEST_SHARED_KEY should not be empty.")

    # Setup test onboarding script and folder
    @omsadmin_test_dir = `#{@prep_omsadmin} #{@base_dir} #{@ruby_test_dir}`.strip()
    assert_equal(0, $?.to_i, "Unexpected failure setting up the test")
    @omsadmin_test_dir_ws = "#{@omsadmin_test_dir}/#{TEST_WORKSPACE_ID}"
  end
  
  def do_onboard
    omsadmin_script = "#{@omsadmin_test_dir}/omsadmin.sh"
    onboard_out = `#{omsadmin_script} -w #{TEST_WORKSPACE_ID} -s #{TEST_SHARED_KEY}`
    assert_equal(0, $?.to_i, "Unexpected failure onboarding : '#{onboard_out}'")
  end

  def load_configurations
    # Mock the configuration
    conf_path = "#{@omsadmin_test_dir_ws}/conf/omsadmin.conf"
    cert_path = "#{@omsadmin_test_dir_ws}/certs/oms.crt"
    key_path = "#{@omsadmin_test_dir_ws}/certs/oms.key"
    agentid_path = @omsadmin_test_dir_ws.gsub(/\/[^\/]*$/, '') + '/agentid'

    conf = %[
      omsadmin_conf_path #{conf_path}
      cert_path #{cert_path}
      key_path #{key_path}
    ]

    success = OMS::Configuration.load_configuration(conf_path, cert_path, key_path, agentid_path)
    assert_equal(true, success, "Configuration should be loaded")

    return conf
  end

end
