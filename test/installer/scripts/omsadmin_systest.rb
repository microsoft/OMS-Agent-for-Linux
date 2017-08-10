require 'digest'
require_relative 'maintenance_systestbase'

class OmsadminTest < MaintenanceSystemTestBase
  
  def check_cert_perms(path)
    stat = File.stat(path)
    assert_equal(nil, stat.world_readable?, "'#{path}' should not be world readable")
    assert_equal(nil, stat.world_writable?, "'#{path}' should not be world writable")
    assert_equal(true, stat.writable?, "'#{path}' should be writable")
    assert_equal(true, stat.readable?, "'#{path}' should be readable")
  end
  
  def post_onboard_validation(ws_dir = @omsadmin_test_dir_ws1)
    crt_path = "#{ws_dir}/certs/oms.crt"
    key_path = "#{ws_dir}/certs/oms.key"
    agentid_path = get_agentid_path(ws_dir)

    # Make sure certs and config was generated
    assert(File.file?(crt_path), "'#{crt_path}' does not exist!")
    assert(File.file?(key_path), "'#{key_path}' does not exist!")
    assert(File.file?("#{ws_dir}/conf/omsadmin.conf"), "omsadmin.conf does not exist!")
    assert(File.file?(agentid_path), "The agentid file does not exist!")
    omsadmin_conf_contents = File.read("#{ws_dir}/conf/omsadmin.conf")
    assert_not_match(/AGENT_GUID=/, omsadmin_conf_contents, "Agent GUID should not be stored in omsadmin.conf")

    # Check permissions
    crt_uid = File.stat(crt_path).uid
    key_uid = File.stat(key_path).uid
    assert(crt_uid == key_uid, "Key and cert should have the same uid")    
    check_cert_perms(crt_path)
    check_cert_perms(key_path)
  end

  def test_create_proxy_file
    assert(!File.file?(@proxy_conf), "Proxy file should not be present beforehand.")
    output = `#{@omsadmin_script} -p proxy_host:8080`
    assert_equal(0, $?.to_i, "Unexpected failure creating proxy file. #{output}")
    assert_match(/Created proxy configuration/, output, "Did not find proxy config create message")
    assert(File.file?(@proxy_conf), "Failed to find generated proxy file.")
    check_cert_perms(@proxy_conf)
    proxy_setting = File.read(@proxy_conf)
    assert_equal("proxy_host:8080", proxy_setting, "Did not find the expected setting in the proxy conf file.")
  end

  def test_onboard_proxy_sucess
    prep_proxy(TEST_PROXY_SETTING)
    output = do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)
    assert_match(/Using proxy settings/, output, "Did not find using proxy settings message: #{output}")
  end

  def test_onboard_proxy_failure
    bad_proxy_setting = TEST_PROXY_SETTING.sub(/(http:\/\/\w+:)\w+(@.*)/, '\1badpassword\2')
    prep_proxy(bad_proxy_setting)
    check_test_keys()
    output = do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY, should_succeed = false)
    assert_match(/Using proxy settings/, output, "Did not find using proxy settings message")
  end

  def test_onboard_success
    output = do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)
    assert_match(/Generating certificate/, output, "Did not find cert generation message")
    post_onboard_validation
  end

  def test_onboard_fail
    require 'securerandom'
    output = do_onboard(SecureRandom.uuid, TEST_SHARED_KEY, false)
    assert_no_match(/HTTP|code/, output)
    assert_match(/Error resolving host during the onboarding request/, output)
  end

  def test_reonboard
    do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)

    crt_path = "#{@omsadmin_test_dir_ws1}/certs/oms.crt"
    key_path = "#{@omsadmin_test_dir_ws1}/certs/oms.key"

    # Save state
    crt_hash = Digest::SHA256.file(crt_path)
    key_hash = Digest::SHA256.file(key_path)
    old_guid = get_GUID()
    
    # Reonboarding should not modify the agent GUID or the certs 
    output = do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)
    assert_match(/Reusing machine's agent GUID/, output, "Did not find GUID reuse message")
    assert_equal(old_guid, get_GUID(), "Agent GUID should not change on reonboarding")
    assert(crt_hash == Digest::SHA256.file(crt_path), "The cert should not change on reonboarding")
    assert(key_hash == Digest::SHA256.file(key_path), "The key should not change on reonboarding")
  end

  def test_reonboard_different_workspace_id
    do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)
    old_guid = get_GUID(@omsadmin_test_dir_ws1)

    output = do_onboard(TEST_WORKSPACE_ID_2, TEST_SHARED_KEY_2)
    new_guid = get_GUID(@omsadmin_test_dir_ws2)

    assert_equal(old_guid, new_guid, "The GUID should not change when reonboarding with a different workspace ID")
    assert_not_match(/Reusing/, output, "Should not print reusing message")
    assert_match(/Using machine's agent GUID/, output, "Should be using GUID from machine")
  end

  def test_onboard_two_workspaces
    $log.info "Test results in #{@omsadmin_test_dir}"
    output1 = do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)
    assert_match(/Generating certificate/, output1, "Did not find cert generation message for workspace 1")
    post_onboard_validation(@omsadmin_test_dir_ws1)

    output2 = do_onboard(TEST_WORKSPACE_ID_2, TEST_SHARED_KEY_2)
    assert_match(/Generating certificate/, output2, "Did not find cert generation message for workspace 2")
    post_onboard_validation(@omsadmin_test_dir_ws2)

    output_list = `#{@omsadmin_script} -l`
    assert_match(/#{TEST_WORKSPACE_ID}/, output_list, "Did not find workspace 1 in list")
    assert_match(/#{TEST_WORKSPACE_ID_2}/, output_list, "Did not find workspace 2 in list")

    remove_workspace(TEST_WORKSPACE_ID)
    remove_workspace(TEST_WORKSPACE_ID, false)

    output_list = `#{@omsadmin_script} -l`

    assert_not_match(/#{TEST_WORKSPACE_ID}/, output_list, "Should not find workspace 1 in list")
    assert_match(/#{TEST_WORKSPACE_ID_2}/, output_list, "Did not find workspace 2 in list")

    output_removeall = `#{@omsadmin_script} -X`
    assert_equal(0, $?.to_i, "Remove all workspace should succeed: #{output_removeall}")

    output_list = `#{@omsadmin_script} -l`
    assert_match(/No Workspace/, output_list, "No workspace should be listed: #{output_list}")
  end

end
