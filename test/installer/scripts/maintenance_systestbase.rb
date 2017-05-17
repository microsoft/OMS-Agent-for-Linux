require 'fluent/test'

class MaintenanceSystemTestBase < Test::Unit::TestCase

  TEST_WORKSPACE_ID = ENV["TEST_WORKSPACE_ID"]
  TEST_SHARED_KEY = ENV["TEST_SHARED_KEY"]
  TEST_WORKSPACE_ID_2 = ENV["TEST_WORKSPACE_ID_2"]
  TEST_SHARED_KEY_2 = ENV["TEST_SHARED_KEY_2"]
  TEST_PROXY_SETTING = ENV["TEST_PROXY_SETTING"]

  def setup
    @base_dir = ENV["BASE_DIR"]
    @ruby_test_dir = ENV["RUBY_TESTING_DIR"]
    @prep_omsadmin = "#{@base_dir}/test/installer/scripts/prep_omsadmin.sh"
    @omsadmin_test_dir = nil
    @omsadmin_test_dir_ws1 = nil
    @omsadmin_test_dir_ws2 = nil
    @omsadmin_script = nil
    @proxy_conf = nil
    prep_omsadmin
  end

  def teardown
    if !@omsadmin_test_dir.nil?
      assert_equal(true, File.directory?(@omsadmin_test_dir))
      FileUtils.rm_r(@omsadmin_test_dir)
      assert_equal(false, File.directory?(@omsadmin_test_dir))
    end
  end

  def check_test_keys
    keys = [TEST_WORKSPACE_ID, TEST_SHARED_KEY, TEST_WORKSPACE_ID_2, TEST_SHARED_KEY_2]
    keys.each_with_index {|key, index| 
      assert(key != nil, "Keys[#{index}] should be set by the environment for this test to run.") 
      assert(key.empty? == false, "Keys[#{index}] should not be empty.")
    }
  end

  def check_proxy_server_working
    output = `curl --proxy #{TEST_PROXY_SETTING} example.com 2>/dev/null`
    return_code = $?.to_i
    assert_equal(0, return_code)
    assert_match(/Example Domain/, output)
  end

  def prep_omsadmin
    # Setup test onboarding script and folder
    @omsadmin_test_dir = `#{@prep_omsadmin} #{@base_dir} #{@ruby_test_dir}`.strip()
    assert_equal(0, $?.to_i, "Unexpected failure setting up the test")
    assert_equal(true, File.directory?(@omsadmin_test_dir), "'#{@omsadmin_test_dir}' does not exist!")

    @omsadmin_test_dir_ws1 = "#{@omsadmin_test_dir}/#{TEST_WORKSPACE_ID}"
    @omsadmin_test_dir_ws2 = "#{@omsadmin_test_dir}/#{TEST_WORKSPACE_ID_2}"

    @omsadmin_script = "#{@omsadmin_test_dir}/omsadmin.sh"
    assert_equal(true, File.file?(@omsadmin_script), "'#{@omsadmin_script}' does not exist!")
    assert_equal(true, File.executable?(@omsadmin_script), "'#{@omsadmin_script}' is not executable.")
    @proxy_conf = "#{@omsadmin_test_dir}/proxy.conf"
  end

  def prep_proxy(proxy_setting)
    proxy_re = /^(https?:\/\/)?(\w+:\w+@)?[^:]+(:\d+)?/
    assert_match(proxy_re, proxy_setting,
                 "Proxy setting not in a valid format : [protocol://][user:password@]proxyhost[:port]")
    assert(@omsadmin_test_dir, "No test directory setup")
    File.write(@proxy_conf, proxy_setting)
    assert(File.file?(@proxy_conf), "Proxy conf file missing!")
    check_proxy_server_working
  end

  def do_onboard(workspace_id, shared_key, should_succeed = true)
    check_test_keys()
    onboard_out = `#{@omsadmin_script} -w #{workspace_id} -s #{shared_key}`
    result = $?
    if should_succeed
      assert_equal(0, result.to_i, "Unexpected failure onboarding : '#{onboard_out}'")
      assert_match(/Onboarding success/, onboard_out, "Did not find onboarding success message")
    else
      assert_not_equal(0, result.to_i, "Onboarding was expected to fail but exited with a return code of 0")
      assert_match(/Error/, onboard_out, "Did not find onboarding error message")
    end
    return onboard_out
  end

  def get_agentid_path(ws_dir)
    omsagent_path = ws_dir.gsub(/\/[^\/]*$/, '')
    agentid_path = omsagent_path + '/agentid'
    return agentid_path
  end

  def get_GUID(ws_dir = @omsadmin_test_dir_ws1)
    agentid_path = get_agentid_path(ws_dir)
    guid = File.read(agentid_path).strip
    return guid
  end

  def remove_workspace(workspace_id, should_succeed = true)
    remove_out = `#{@omsadmin_script} -x #{workspace_id}`
    result = $?
    if should_succeed
      assert_equal(0, result.to_i, "Unexpected failure removing workspace: '#{remove_out}'")
    else
      assert_equal(0, result.to_i, "Unexpected failure removing workspace: '#{remove_out}'")
      assert_match(/Workspace #{workspace_id} doesn't exist/, remove_out, "Removing workspace message is not expected  #{remove_out}")
    end
    return remove_out
  end
end
