require 'test/unit'
require 'tempfile'
require_relative '../../../source/code/plugins/agent_maintenance_script.rb'
require_relative '../../../source/code/plugins/agent_common'
require_relative 'omstestlib'

class MaintenanceUnitTest < Test::Unit::TestCase

  # Constants for testing
  VALID_AGENT_GUID = "4d593017-2e94-4d54-84ad-12d9d05e02ce"
  VALID_WORKSPACE_ID = "368a6f2a-1d36-4899-9415-20f44a5acd5d"
  VALID_DSC_ENDPOINT_NO_ESC = "https://oaasagentsvcdf.cloudapp.net/Accounts/#{VALID_WORKSPACE_ID}"\
                              "/Nodes(AgentId='#{VALID_AGENT_GUID}')"
  VALID_CERTIFICATE_UPDATE_ENDPOINT = "https://#{VALID_WORKSPACE_ID}.oms.int2.microsoftatlanta-"\
                                      "int.com/ConfigurationService.Svc/RenewCertificate"

  VALID_OMSADMIN_CONF = "WORKSPACE_ID=#{VALID_WORKSPACE_ID}\n"\
                        "AGENT_GUID=#{VALID_AGENT_GUID}\n"\
                        "LOG_FACILITY=local0\n"\
                        "CERTIFICATE_UPDATE_ENDPOINT=#{VALID_CERTIFICATE_UPDATE_ENDPOINT}\n"\
                        "URL_TLD=int2.microsoftatlanta-int.com\n"\
                        "DSC_ENDPOINT=https://oaasagentsvcdf.cloudapp.net/Accounts/"\
                        "#{VALID_WORKSPACE_ID}/Nodes(AgentId='#{VALID_AGENT_GUID}')\n"\
                        "OMS_ENDPOINT=https://#{VALID_WORKSPACE_ID}.ods."\
                        "int2.microsoftatlanta-int.com/OperationalData.svc/PostJsonDataItems\n"\
                        "AZURE_RESOURCE_ID=\n"\
                        "OMSCLOUD_ID=7783-7084-3265-9085-8269-3286-77\n"\
                        "UUID=274E8EF9-2B6F-8A45-801B-AAEE62710796\n"\

  VALID_HEARTBEAT_RESP = "<?xml version=\"1.0\" encoding=\"utf-8\"?><LinuxAgentTopologyResponse "\
                         "queryInterval=\"PT1H\" telemetryReportInterval=\"PT10M\" id=\"628a6594-a618-4da4-a989-bcd9a322d403\" "\
                         "xmlns=\"http://schemas.microsoft.com/WorkloadMonitoring/HealthServiceProtocol/2014/09/\" "\
                         "xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/"\
                         "XMLSchema-instance\"><CertificateUpdateEndpoint updateCertificate=\"false\">"\
                         "#{VALID_CERTIFICATE_UPDATE_ENDPOINT}</CertificateUpdateEndpoint><DscConfiguration>"\
                         "<Endpoint>#{VALID_DSC_ENDPOINT_NO_ESC}</Endpoint><NodeConfigurationName>"\
                         "MicrosoftOperationsManagementLinuxConfiguration.common</NodeConfigurationName>"\
                         "</DscConfiguration></LinuxAgentTopologyResponse>"

  EMPTY_CERTIFICATE_UPDATE_ENDPOINT = "CERTIFICATE_UPDATE_ENDPOINT=\n"
  EMPTY_DSC_ENDPOINT = "DSC_ENDPOINT=\n"

  def setup
    @omsadmin_conf_file = Tempfile.new("omsadmin_conf")
    @cert_file = Tempfile.new("oms_crt")
    @key_file = Tempfile.new("oms_key")
    @pid_file = Tempfile.new("omsagent_pid")  # doesn't need to have meaningful data for testing
    @proxy_file = Tempfile.new("proxy_conf")
    @os_info_file = Tempfile.new("os_info")
    @install_info_file = Tempfile.new("install_info")
    @log = OMS::MockLog.new
  end

  def teardown
    @omsadmin_conf_file.unlink
    @cert_file.unlink
    @key_file.unlink
    @pid_file.unlink
    @proxy_file.unlink
    @os_info_file.unlink
    @install_info_file.unlink
  end

  # Helper to create a new Maintenance class object to test
  def get_new_maintenance_obj(omsadmin_path = @omsadmin_conf_file.path,
       cert_path = @cert_file.path, key_path = @key_file.path, pid_path = @pid_file.path,
       proxy_path = @proxy_file.path, os_info_path = @os_info_file.path,
       install_info_path = @install_info_file.path, log = @log, verbose = false)

    m = MaintenanceModule::Maintenance.new(omsadmin_path, cert_path, key_path, pid_path,
         proxy_path, os_info_path, install_info_path, log, verbose)
    m.suppress_stdout = true
    return m
  end

  # Helper to remove escape characters (\) and use one encoding
  def no_esc_and_encode(message)
    return message.encode("UTF-8").gsub(/\\/,"")
  end

  def test_load_config_nonexistent_file
    m = get_new_maintenance_obj("/etc/nonexistentomsadmin.conf")
    assert_equal(m.load_config_return_code, OMS::MISSING_CONFIG_FILE,
                 "load_config succeeded with nonexistent config")
  end

  def test_load_config_return_code
    File.write(@omsadmin_conf_file.path, VALID_OMSADMIN_CONF)
    m = get_new_maintenance_obj
    assert_equal(m.load_config_return_code, 0, "load_config failed with valid config")
  end

  def test_generate_certs_empty_input
    File.write(@cert_file.path, "")
    File.write(@key_file.path, "")
    m = get_new_maintenance_obj
    assert_equal(m.generate_certs("", ""), OMS::MISSING_CONFIG,
                 "Incorrect return code for empty WORKSPACE_ID and AGENT_GUID")
    assert(File.zero?(@cert_file.path), "Cert file is non-empty after invalid generate_certs")
    assert(File.zero?(@key_file.path), "Key file is non-empty after invalid generate_certs")
  end

  def test_generate_certs_valid_input
    File.write(@cert_file.path, "")
    File.write(@key_file.path, "")
    m = get_new_maintenance_obj
    assert_equal(m.generate_certs(VALID_WORKSPACE_ID, VALID_AGENT_GUID), 0, "generate_certs failed")
    assert(!File.zero?(@cert_file.path), "Cert file is empty after valid generate_certs")
    assert(!File.zero?(@key_file.path), "Key file is empty after valid generate_certs")
  end

  def test_apply_dsc_endpoint_empty_xml
    File.write(@omsadmin_conf_file.path, EMPTY_DSC_ENDPOINT)
    m = get_new_maintenance_obj
    assert_equal(m.apply_dsc_endpoint(""), OMS::ERROR_EXTRACTING_ATTRIBUTES,
                 "Incorrect return code for empty input")
    @omsadmin_conf_file.rewind
    assert_equal(@omsadmin_conf_file.read, EMPTY_DSC_ENDPOINT,
                 "conf written by apply_dsc_endpoint on empty input")
  end

  def test_apply_dsc_endpoint_valid_xml
    File.write(@omsadmin_conf_file.path, EMPTY_DSC_ENDPOINT)
    m = get_new_maintenance_obj
    assert_equal(m.apply_dsc_endpoint(VALID_HEARTBEAT_RESP).class, String,
                 "apply_dsc_endpoint failed with valid input")
    @omsadmin_conf_file.rewind
    assert_equal(no_esc_and_encode(@omsadmin_conf_file.read),
        no_esc_and_encode("DSC_ENDPOINT=#{VALID_DSC_ENDPOINT_NO_ESC}\n"),
        "conf was not updated correctly by apply_dsc_endpoint")
  end

  def test_apply_certificate_update_endpoint_empty_xml
    File.write(@omsadmin_conf_file.path, EMPTY_CERTIFICATE_UPDATE_ENDPOINT)
    m = get_new_maintenance_obj
    assert_equal(m.apply_certificate_update_endpoint("", false),
                 OMS::MISSING_CERT_UPDATE_ENDPOINT,
                 "Incorrect return code for empty input")
    @omsadmin_conf_file.rewind
    assert_equal(@omsadmin_conf_file.read, EMPTY_CERTIFICATE_UPDATE_ENDPOINT,
                 "conf written by apply_certificate_update_endpoint on empty input")
  end

  def test_apply_certificate_update_endpoint_valid_xml
    File.write(@omsadmin_conf_file.path, EMPTY_CERTIFICATE_UPDATE_ENDPOINT)
    m = get_new_maintenance_obj
    assert_equal(m.apply_certificate_update_endpoint(VALID_HEARTBEAT_RESP).class, String,
                 "apply_certificate_update_endpoint failed with valid input")
    @omsadmin_conf_file.rewind
    assert_equal(@omsadmin_conf_file.read,
                 "CERTIFICATE_UPDATE_ENDPOINT=#{VALID_CERTIFICATE_UPDATE_ENDPOINT}\n",
                 "conf was not updated correctly by apply_certificate_update_endpoint")
  end

  def test_apply_endpoints_file_nonexistent_xml
    output_file = Tempfile.new("output.txt")

    File.write(@omsadmin_conf_file.path,
               "#{EMPTY_CERTIFICATE_UPDATE_ENDPOINT}#{EMPTY_DSC_ENDPOINT}")
    m = get_new_maintenance_obj
    assert_equal(m.apply_endpoints_file("/etc/nonexistentxml.txt", output_file.path),
                 OMS::MISSING_CONFIG_FILE,
                 "Incorrect return code for nonexistent xml")
    @omsadmin_conf_file.rewind
    omsadmin_conf_result = @omsadmin_conf_file.read
    assert_match(/^#{EMPTY_CERTIFICATE_UPDATE_ENDPOINT}/, omsadmin_conf_result,
                 "conf written with CERTIFICATE_UPDATE_ENDPOINT by apply_endpoints_file on "\
                 "nonexistent input")
    assert_match(/^#{EMPTY_DSC_ENDPOINT}/, omsadmin_conf_result,
        "conf written with DSC_ENDPOINT by apply_endpoints_file on nonexistent input")

    output_file.unlink
  end

  def test_apply_endpoints_file_invalid_output_file
    hb_resp_file = Tempfile.new("hb_server_resp")
    File.write(hb_resp_file, VALID_HEARTBEAT_RESP)

    m = get_new_maintenance_obj
    assert_equal(m.apply_endpoints_file(hb_resp_file.path,
                                        "/etc/nonexistentdir/nonexistentfile.txt"),
                 OMS::ERROR_WRITING_TO_FILE, "Incorrect return code for invalid output file")

    hb_resp_file.unlink
  end

  def test_apply_endpoints_file_valid
    hb_resp_file = Tempfile.new("hb_server_resp")
    File.write(hb_resp_file, VALID_HEARTBEAT_RESP)
    output_file = Tempfile.new("output.txt")

    File.write(@omsadmin_conf_file.path,
               "#{EMPTY_CERTIFICATE_UPDATE_ENDPOINT}#{EMPTY_DSC_ENDPOINT}")
    m = get_new_maintenance_obj
    assert_equal(m.apply_endpoints_file(hb_resp_file.path, output_file.path), 0,
        "apply_endpoints_file failed with valid input")
    @omsadmin_conf_file.rewind
    omsadmin_conf_result = no_esc_and_encode(@omsadmin_conf_file.read)
    assert_match(/^CERTIFICATE_UPDATE_ENDPOINT=#{VALID_CERTIFICATE_UPDATE_ENDPOINT}\n/,
                 omsadmin_conf_result,
                 "conf was not updated correctly with CERTIFICATE_UPDATE_ENDPOINT")
    omsadmin_conf_dsc = omsadmin_conf_result.sub(/^CERTIFICATE_UPDATE_ENDPOINT=#{VALID_CERTIFICATE_UPDATE_ENDPOINT}\n/, "")
    assert_equal(omsadmin_conf_dsc, "DSC_ENDPOINT=#{VALID_DSC_ENDPOINT_NO_ESC}\n",
                 "conf was not updated correctly with DSC_ENDPOINT")

    hb_resp_file.unlink
    output_file.unlink
  end

end

