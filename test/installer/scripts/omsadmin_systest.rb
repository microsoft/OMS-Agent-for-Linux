require 'digest'
require 'fileutils'
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

    # Make sure certs and config was generated
    assert(File.file?(crt_path), "'#{crt_path}' does not exist!")
    assert(File.file?(key_path), "'#{key_path}' does not exist!")
    assert(File.file?("#{ws_dir}/conf/omsadmin.conf"), "omsadmin.conf does not exist!")

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
    assert_match(/Reusing previous agent GUID/, output, "Did not find GUID reuse message")
    assert_equal(old_guid, get_GUID(), "Agent GUID should not change on reonboarding")
    assert(crt_hash == Digest::SHA256.file(crt_path), "The cert should not change on reonboarding")
    assert(key_hash == Digest::SHA256.file(key_path), "The key should not change on reonboarding")
  end

  def test_reonboard_different_workspace_id
    do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)
    old_guid = get_GUID(@omsadmin_test_dir_ws1)

    output = do_onboard(TEST_WORKSPACE_ID_2, TEST_SHARED_KEY_2)
    new_guid = get_GUID(@omsadmin_test_dir_ws2)

    assert_not_equal(old_guid, new_guid, "The GUID should change when reonboarding with a different workspace ID")
    assert_not_match(/Reusing/, output, "Should not be reusing GUID")
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

  def test_set_proc_limit_default
    set_omsagent_proc_limit()
    assert(FileUtils.compare_file(@proc_limits_conf, "#{@omsadmin_test_dir}/limits-default.conf"),
           "The user process limit was not set correctly to the default value")
  end

  def test_set_proc_limit_non_default
    set_omsagent_proc_limit(5000)
    assert(FileUtils.compare_file(@proc_limits_conf, "#{@omsadmin_test_dir}/limits-non-default.conf"),
           "The user process limit was not set correctly to the new value")
  end

  def test_set_proc_limit_string
    FileUtils.cp(@proc_limits_conf, "#{@omsadmin_test_dir}/limits-original.conf")
    output = set_omsagent_proc_limit("NaN", false)
    assert(FileUtils.compare_file(@proc_limits_conf, "#{@omsadmin_test_dir}/limits-original.conf"),
           "Process limit conf file was wrongly changed")
    assert_match(/New process limit must be a positive numerical value/, output,
                 "Did not find correct error message")
  end

  def test_set_proc_limit_below_min
    FileUtils.cp(@proc_limits_conf, "#{@omsadmin_test_dir}/limits-original.conf")
    output = set_omsagent_proc_limit(1, false)
    assert(FileUtils.compare_file(@proc_limits_conf, "#{@omsadmin_test_dir}/limits-original.conf"),
           "Process limit conf file was wrongly changed")
    assert_match(/New process limit must be at least/, output, "Did not find correct error message")
  end

  def test_unset_proc_limit_when_set
    FileUtils.cp("#{@omsadmin_test_dir}/limits-two-settings.conf", @proc_limits_conf)
    output = unset_proc_limit
    assert_match(/Removing process limit/, output, "Did not find expected removal message")
    assert(FileUtils.compare_file(@proc_limits_conf,
                                  "#{@omsadmin_test_dir}/limits-no-settings.conf"),
           "Process limit conf file was not cleared out correctly")
  end

  def test_unset_proc_limit_when_not_set
    FileUtils.cp("#{@omsadmin_test_dir}/limits-no-settings.conf", @proc_limits_conf)
    output = unset_proc_limit
    assert_not_match(/Removing process limit/, output, "Should not have found a limit")
    assert(FileUtils.compare_file(@proc_limits_conf,
                                  "#{@omsadmin_test_dir}/limits-no-settings.conf"),
           "Process limit conf file was wrongly changed")
  end

  def set_omsagent_proc_limit(val = nil, should_succeed = true)
    if val.nil?
      val = 75
      set_proc_limit_cmd = "#{@omsadmin_script} -N"
    else
      set_proc_limit_cmd = "#{@omsadmin_script} -n #{val}"
    end
    output = `#{set_proc_limit_cmd}`
    ret_code = $?

    if should_succeed
      assert_equal(0, ret_code.to_i, "The command to set the user process limit was unsuccessful")
      assert_match(/Setting process limit for the .* user in .* to #{val}.../, output,
                   "Did not find correct setting message")
    else
      assert_not_equal(0, ret_code.to_i, "The command to set the user process limit was " \
                                         "unexpectedly successful")
    end
    return output
  end

  def unset_proc_limit
    output = `#{@omsadmin_script} -r`
    ret_code = $?
    assert_equal(0, ret_code.to_i, "The command to unset the proc limit failed")
    return output
  end

end
