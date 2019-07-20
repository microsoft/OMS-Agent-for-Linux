require 'tempfile' 
require_relative ENV["BASE_DIR"] + '/source/code/plugins/agent_maintenance_script'
require_relative ENV["BASE_DIR"] + '/source/code/plugins/oms_common'
require_relative 'maintenance_systestbase'
require_relative '../../code/plugins/omstestlib'

class AgentMaintenanceSystemTest < MaintenanceSystemTestBase

  FAKE_CERT = "-----BEGIN CERTIFICATE-----\n"\
               "MIIDzTCCArWgAwIBAgIJAOE3pIATfJnUMA0GCSqGSIb3DQEBCwUAMH0xFzAVBgNV\n"\
               "BAMMDmZha2Utd29ya3NwYWNlMS0wKwYDVQQDDCQyYTg3YjkyZC0yZDdjLTQ0ZmEt\n"\
               "YjM3Ny0zNjZlOWIzNTM3YmMxHzAdBgNVBAsMFkxpbnV4IE1vbml0b3JpbmcgQWdl\n"\
               "bnQxEjAQBgNVBAoMCU1pY3Jvc29mdDAeFw0xNTExMjAyMzQwMjFaFw0xNjExMTky\n"\
               "MzQwMjFaMH0xFzAVBgNVBAMMDmZha2Utd29ya3NwYWNlMS0wKwYDVQQDDCQyYTg3\n"\
               "YjkyZC0yZDdjLTQ0ZmEtYjM3Ny0zNjZlOWIzNTM3YmMxHzAdBgNVBAsMFkxpbnV4\n"\
               "IE1vbml0b3JpbmcgQWdlbnQxEjAQBgNVBAoMCU1pY3Jvc29mdDCCASIwDQYJKoZI\n"\
               "hvcNAQEBBQADggEPADCCAQoCggEBAOT1+CHaw5wiLFTYFP9FudR4Vt8mADpzgt+J\n"\
               "71rfWG7ZZSvNDMMr6LglBXg045mNyUh7N2zAQbMbEyWDs82TD7x59EPRfOfb8pE/\n"\
               "lKPTG9c05b3ANY4yY0fGOPb0SWaHeDn+kBicNWQmfwVlKk98xeGohJCFqwTGMrXV\n"\
               "Pd3zy9p9vrpiQ2yS8bfPbd+NoWnY/EyWmDRhqfUa9rciqJBvnCvebNYnvWl4X0ri\n"\
               "1DY+11eJS4Y4qM+bAm3MG15fqr+B+biToeJGCAfEMRwZFEUdYaNvg6ADQu4vcn6B\n"\
               "q9gZlInCN+yyMOQMWfSqyeGoTOkZVGPcDZeSMmpWgd+doNq54LECAwEAAaNQME4w\n"\
               "HQYDVR0OBBYEFKxFIJKRXiYteAeNeXnq/mFONmEeMB8GA1UdIwQYMBaAFKxFIJKR\n"\
               "XiYteAeNeXnq/mFONmEeMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEB\n"\
               "AGCup0o6x2Kc+KbVycwr+6sYBCY17WJNC6btgAlE7PUzc3X+vtsKjQwdvRnSrlSM\n"\
               "UlxhMdOYN2VjufSGaCSaNsHsXMtHBMjt7C3w3si+e0rBu4LgK6MfEiKmnSvqsb+g\n"\
               "K5JDm2RKGT6oMqKzes5el12b1uw9pB9mbwcD9AGNNIDcgdn7VtVuL9UVDw7uINx5\n"\
               "4phgHLFZDTsbFH6JXwD9Msv6e1vMLZTbGpbbaYfbyTvkeYNzC0zcgEMw7ZeBpYEk\n"\
               "Bn35DO1ax2QdO/nsMNTIkAO67nUtzzIWyC45PVJ+u7YGbkXb5fAdeGtHXyIzHIEn\n"\
               "207V8aTDQntaZeNsLWUnXug=\n"\
               "-----END CERTIFICATE-----\n"

  FAKE_KEY = "-----BEGIN RSA PRIVATE KEY-----\n"\
              "MIIEowIBAAKCAQEA5PX4IdrDnCIsVNgU/0W51HhW3yYAOnOC34nvWt9YbtllK80M\n"\
              "wyvouCUFeDTjmY3JSHs3bMBBsxsTJYOzzZMPvHn0Q9F859vykT+Uo9Mb1zTlvcA1\n"\
              "jjJjR8Y49vRJZod4Of6QGJw1ZCZ/BWUqT3zF4aiEkIWrBMYytdU93fPL2n2+umJD\n"\
              "bJLxt89t342hadj8TJaYNGGp9Rr2tyKokG+cK95s1ie9aXhfSuLUNj7XV4lLhjio\n"\
              "z5sCbcwbXl+qv4H5uJOh4kYIB8QxHBkURR1ho2+DoANC7i9yfoGr2BmUicI37LIw\n"\
              "5AxZ9KrJ4ahM6RlUY9wNl5IyalaB352g2rngsQIDAQABAoIBAGWLmZMaPSsgFN1E\n"\
              "QHu+5t4OySiK6AsEdATEXj3FVKlFDZPRi1l8Peh9suFPQ6o0shLNYxV+ZyUSWvmG\n"\
              "YdZI5O/IfscdP/JtIDW/JyNJW82kjkgL2TTJsDKC/Xy5d1xbtLyz5CCmFx/l2uv/\n"\
              "pDZAtlqQrMqUHfcuGAuBGcE4gS7TQzt4x8eHtCYlriBebnyJA+Mn8L7rM3oOT0Nh\n"\
              "2Oy/TgH49xY2ODbja7hn6RbsA11Jn2byUVPaopcNOPTmtPBVWoliDFRan+Q+dPfm\n"\
              "InbExJQrCZCcc3/mijye8j6b9RCsoZ7JKzsFaLzU7RSHt3LPaQzbAyQ/KtZ/xBg8\n"\
              "KP1gj2ECgYEA+8EQHqkX4yGdADBcLFR+Ai0hcmKq9gpyBO796R5Mm+lhDni6sH6z\n"\
              "m+tpqDd+HICj+NJqAf5zetBQUexi8Xi7y8aZezyxknaXgr4r8EFSNywyGRpo99ii\n"\
              "FTALq8t/pyM1BS6tStI5+NQWJL0f0rFrOl/Y+MZ7emiQfbakGQ1MmmUCgYEA6NJ/\n"\
              "Qy6ew/z3AqeYnxG7JtQVjTHN7wERdfNTcVXYSe6vqv9wIRyfXGoQML5uM140x1Oq\n"\
              "pNw3jjk83aGNByTBwBvTT+7Zqq/AUe/7GzMGw3HM26qqKdvqUWx3dGIV4zaoqFP8\n"\
              "rB1EFj5RX7V2hx/taVWEN677tI6r1cMNNp5dAl0CgYEAjSAi6y0bCOYU3sA9S1Rp\n"\
              "9spZz4dkEty0IfPfPkkP5O6ky7n93WaJRMRozDWfalbqlFdPuaJsFdKk0+fRZ0+o\n"\
              "5oiEDUNuv43fTRlSBDJ55hfOVagqY5V69qmiQUGoY4cm96q81g6XFNe/OgUSy8dN\n"\
              "NsH4HS0Wlv360Z4Ky0hbQskCgYA7rrow3qKUWyR26b+WB1WSfouHxlykCAIR2m5p\n"\
              "fzgSu70MeK6lzlCLwCSmWiqlwGCHOEtmN42GR+XyapdcXW/Nb1ScCP6DYspKNtqH\n"\
              "/mydbW62YOl+EYHfnY6BpyM1O63AeMcs19O8X/08K6hWuziA6Ascux6LCofCJF4e\n"\
              "wjnVgQKBgHaH990opFVun6+RDi6MZabRHRxfNEHTxTRK2x+9qDiZu/kAlUdlTWSt\n"\
              "baBu6DoyHxNsyNg/39rA+8PYQBgbMOfO7t4TGv2FTT8kVlNdVCEVvPVNfFEnlqOu\n"\
              "pMbKdhdK/zhvgRUpKON8rnw/vnpKEs5qQi3LHyp/WooEw9VqZcoW\n"\
              "-----END RSA PRIVATE KEY-----\n"

  def setup
    super
    onboarded_output = do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)
    assert_no_match(/(e|E)rror/, onboarded_output, "Unexpected error onboarding for maintenance tests")
    # Onboarded valid data
    @omsadmin_conf_path = "#{@omsadmin_test_dir_ws1}/conf/omsadmin.conf"
    @cert_path = "#{@omsadmin_test_dir_ws1}/certs/oms.crt"
    @key_path = "#{@omsadmin_test_dir_ws1}/certs/oms.key"
    @pid_path = Tempfile.new("omsagent_pid")  # this does not need to be meaningful during testing
    @os_info_path = "#{@omsadmin_test_dir}/scx-release"
    @install_info_path = "#{@base_dir}/installer/conf/installinfo.txt"
    @log = OMS::MockLog.new

    @test_omsadmin_conf = Tempfile.new("omsadmin_conf")
    @test_cert = Tempfile.new("oms_crt")
    @test_key = Tempfile.new("oms_key")
    @test_os_info = Tempfile.new("os_info")
  end

  def teardown
    @pid_path.unlink
    @test_omsadmin_conf.unlink
    @test_cert.unlink
    @test_key.unlink
    @test_os_info.unlink
    super
  end

  # Helper to create a new Maintenance class object to test; uses valid files by default
  def get_new_maintenance_obj(omsadmin_path = @omsadmin_conf_path, cert_path = @cert_path,
       key_path = @key_path, pid_path = @pid_path.path, proxy_path = @proxy_conf,
       os_info_path = @os_info_path, install_info_path = @install_info_path, log = @log,
       verbose = false)

    m = MaintenanceModule::Maintenance.new(omsadmin_path, cert_path, key_path, pid_path,
         proxy_path, os_info_path, install_info_path, log, verbose)
    m.suppress_stdout = true
    return m
  end

  def test_heartbeat_nonexistent_config
    m = get_new_maintenance_obj("/etc/nonexistentomsadmin.conf")
    assert_equal(OMS::MISSING_CONFIG_FILE, m.heartbeat, "Incorrect return code for nonexistent config")
  end

  def test_heartbeat_empty_config
    File.write(@test_omsadmin_conf.path, "")
    m = get_new_maintenance_obj(@test_omsadmin_conf.path)
    assert_equal(OMS::MISSING_CONFIG, m.heartbeat, "Incorrect return code for empty config")
  end

  def test_heartbeat_nonexistent_certs
    m = get_new_maintenance_obj(@omsadmin_conf_path, "/etc/nonexistentoms.crt", "/etc/nonexistentoms.key")
    assert_equal(OMS::MISSING_CERTS, m.heartbeat, "Incorrect return code for nonexistent certs")
  end

  def test_heartbeat_empty_certs
    File.write(@test_cert.path, "")
    File.write(@test_key.path, "")
    m = get_new_maintenance_obj(@omsadmin_conf_path, @test_cert.path, @test_key.path)
    assert_equal(OMS::MISSING_CERTS, m.heartbeat, "Incorrect return code for empty cert files")
  end

  def test_heartbeat_malformed_os_info
    File.write(@test_os_info.path, "Malformed OS Name\nMalformed OS Version\n")
    m = get_new_maintenance_obj(@omsadmin_conf_path, @cert_path, @key_path, @pid_path.path,
            @proxy_conf, @test_os_info.path)
    assert_equal(0, m.heartbeat, "Heartbeat failed with malformed os_info")
  end

  def test_heartbeat_valid
    valid_omsadmin_conf = File.read(@omsadmin_conf_path)
    remove_existing_cert_update_endpoint = valid_omsadmin_conf.sub(/^CERTIFICATE_UPDATE_ENDPOINT=.*\n/,
        "CERTIFICATE_UPDATE_ENDPOINT=\n")
    remove_existing_dsc_endpoint = remove_existing_cert_update_endpoint.sub(/^DSC_ENDPOINT=.*\n/,
        "DSC_ENDPOINT=\n")
    File.write(@test_omsadmin_conf.path, remove_existing_dsc_endpoint)
    m = get_new_maintenance_obj(@test_omsadmin_conf.path)
    assert_equal(0, m.heartbeat, "Heartbeat failed with valid data")
    final_omsadmin_conf = File.read(@test_omsadmin_conf.path)
    assert_no_match(/CERTIFICATE_UPDATE_ENDPOINT=\n/, final_omsadmin_conf,
        "CERTIFICATE_UPDATE_ENDPOINT was not updated in omsadmin.conf")
    assert_no_match(/DSC_ENDPOINT=\n/, final_omsadmin_conf, "DSC_ENDPOINT was not updated in omsadmin.conf")
  end

  def test_heartbeat_valid_with_proxy
    prep_proxy(TEST_PROXY_SETTING)
    valid_omsadmin_conf = File.read(@omsadmin_conf_path)
    remove_existing_cert_update_endpoint = valid_omsadmin_conf.sub(/^CERTIFICATE_UPDATE_ENDPOINT=.*\n/,
        "CERTIFICATE_UPDATE_ENDPOINT=\n")
    remove_existing_dsc_endpoint = remove_existing_cert_update_endpoint.sub(/^DSC_ENDPOINT=.*\n/,
        "DSC_ENDPOINT=\n")
    File.write(@test_omsadmin_conf.path, remove_existing_dsc_endpoint)
    m = get_new_maintenance_obj(@test_omsadmin_conf.path)
    assert_equal(0, m.heartbeat, "Heartbeat failed with valid data and valid proxy")
    final_omsadmin_conf = File.read(@test_omsadmin_conf.path)
    assert_no_match(/CERTIFICATE_UPDATE_ENDPOINT=\n/, final_omsadmin_conf,
        "CERTIFICATE_UPDATE_ENDPOINT was not updated in omsadmin.conf")
    assert_no_match(/DSC_ENDPOINT=\n/, final_omsadmin_conf, "DSC_ENDPOINT was not updated in omsadmin.conf with valid proxy")
  end

  def test_renew_certs_nonexistent_config
    m = get_new_maintenance_obj("/etc/nonexistentomsadmin.conf")
    assert_equal(OMS::MISSING_CONFIG_FILE, m.renew_certs, "Incorrect return code for nonexistent config")
  end

  def test_renew_certs_empty_config
    File.write(@test_omsadmin_conf.path, "")
    m = get_new_maintenance_obj(@test_omsadmin_conf.path)
    assert_equal(OMS::MISSING_CONFIG, m.renew_certs, "Incorrect return code for empty config")
  end

  def test_renew_certs_nonexistent_certs
    m = get_new_maintenance_obj(@omsadmin_conf_path, "/etc/nonexistentoms.crt", "/etc/nonexistentoms.key")
    assert_equal(OMS::MISSING_CERTS, m.renew_certs, "Incorrect return code for nonexistent certs")
  end

  def test_renew_certs_empty_certs
    File.write(@test_cert.path, "")
    File.write(@test_key.path, "")
    m = get_new_maintenance_obj(@omsadmin_conf_path, @test_cert.path, @test_key.path)
    assert_equal(OMS::MISSING_CERTS, m.renew_certs, "Incorrect return code for empty cert files")
  end

  def test_renew_certs_fake_certs
    File.write(@test_cert.path, FAKE_CERT)
    File.write(@test_key.path, FAKE_KEY)
    m = get_new_maintenance_obj(@omsadmin_conf_path, @test_cert.path, @test_key.path)
    assert_not_equal(0, m.renew_certs, "Renew certs succeeded with fake cert files")
    assert_equal(FAKE_CERT, File.read(@test_cert.path), "Old certificate was not restored from failed renew_certs")
    assert_equal(FAKE_KEY, File.read(@test_key.path), "Old private key was not restored from failed renew_certs")
  end

  def test_renew_certs_valid_no_prior_heartbeat
    m = get_new_maintenance_obj
    assert_equal(0, m.renew_certs,
        "Renew certs should pass since onboard should fill in CERTIFICATE_UPDATE_ENDPOINT")
  end

  def test_renew_certs_valid_no_prior_heartbeat_with_proxy
    prep_proxy(TEST_PROXY_SETTING)
    m = get_new_maintenance_obj
    assert_equal(0, m.renew_certs,
        "Renew certs should pass since onboard should fill in CERTIFICATE_UPDATE_ENDPOINT with valid proxy")
  end

  def test_renew_certs_valid_with_heartbeat
    m = get_new_maintenance_obj
    assert_equal(0, m.heartbeat, "Heartbeat failed with valid data")
    assert_equal(0, m.renew_certs, "Renew certs failed with valid data and valid heartbeat")
  end

  def test_renew_certs_valid_with_heartbeat_with_proxy
    prep_proxy(TEST_PROXY_SETTING)
    m = get_new_maintenance_obj
    assert_equal(0, m.heartbeat, "Heartbeat failed with valid data and valid proxy")
    assert_equal(0, m.renew_certs, "Renew certs failed with valid data and valid heartbeat and valid proxy")
  end
end
