require 'test/unit'
require_relative '../../../source/code/plugins/agent_topology_request_script.rb'
require 'rexml/document'
require 'flexmock/test_unit'


# Sample xml:
# <AgentTopologyRequest><FullyQualfiedDomainName>abc.xyz.com</FullyQualfiedDomainName><EntityTypeId>f2aa1565-ec8c-4d63-8456-7d2bb47dafc5</EntityTypeId>
# <AuthenticationCertificate>MIIEAzCCAuugAwIBAgIJAM7BHSoGI3jvMA0GCSqGSIb3DQEBCwUAMIGXMS0wKwYD
# VQQDDCRjZWM5ZWE2Ni1mNzc1LTQxY2QtYTBhNi0yZDBmMGZmZGFjNmYxLTArBgNV
# BAMMJGYyYWExNTY1LWVjOGMtNGQ2My04NDU2LTdkMmJiNDdkYWZjNTEjMCEGA1UE
# CwwaTWljcm9zb2Z0IE1vbml0b3JpbmcgQWdlbnQxEjAQBgNVBAoMCU1pY3Jvc29m
# dDAeFw0xNTEwMTAwNTUxMTlaFw0xNjEwMDkwNTUxMTlaMIGXMS0wKwYDVQQDDCRj
# ZWM5ZWE2Ni1mNzc1LTQxY2QtYTBhNi0yZDBmMGZmZGFjNmYxLTArBgNVBAMMJGYy
# YWExNTY1LWVjOGMtNGQ2My04NDU2LTdkMmJiNDdkYWZjNTEjMCEGA1UECwwaTWlj
# cm9zb2Z0IE1vbml0b3JpbmcgQWdlbnQxEjAQBgNVBAoMCU1pY3Jvc29mdDCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALm94erWxsNoV/5TCyzgkSceZnfj
# FoEolfigtoO3cLryF7GlKb7PDsUtjOz2dqVQ9HVXfLxI29mng3kxGf9FCWIU8OQq
# oEtBzhKnQz12PMQXivypC3+h3fWgAVD+oTvK3omZPIu1NNMfjIuRTa0aucWt91Qy
# J7Yga4XgUp0RpcduXeYj9AN0TEEglLm7Y5aWMLU23eR3v0Jgz3WfLWBXsVRq+pNd
# tqVfNLcFz5AQ1NxFDhbTOoJ08xCkKU+bfgEP+YxTF1cqkeYXcRKAcKzwoO289lO6
# n7Gt02s0M3BtHsc8HJHjKLx2SGFevsMKLYGtEMSmqbcCSksew5fqhVcsQ+0CAwEA
# AaNQME4wHQYDVR0OBBYEFNcHWcVg1c4ysrvkydceAcV3BJloMB8GA1UdIwQYMBaA
# FNcHWcVg1c4ysrvkydceAcV3BJloMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEL
# BQADggEBABMA/uxfT4//JyNd5NpwySSRAczC6+IXpOAjHZdj31A0CTOsuzsxT/JC
# sPLLXXV3KC60+i3Lfd3Pl2QJAl9f84IdscLYTfVtBkNvCkm0hv4r250L9SpV5QFz
# EfimZr8wKZpk8ZRM1J2E9Sdz3eW3vp44GohNH3y2vH7CDVRSE+5lsbi0iTSPWVnL
# EbJ+2XtM3lmf5cbvK1eB/pT0JN/o7ttL24eBOR9kcs6GbScIOeimDw6buCX0PMXm
# lux69/gTh0mAjeU0ro5rEaxvEus4uyCfzzm1Q+EsZJaIffGyqW791HocM6Ivw5gI
# J/rP/YZfFehxmvTHEy60g7OeQuybknk=
# </AuthenticationCertificate><OperatingSystem><InContainer>False</InContainer><Telemetry PercentUserTime=\"0\" PercentPrivilegedTime=\"0\" UsedMemory=\"209576\" PercentUsedMemory=\"21\"></Telemetry><ProcessorArchitecture>x64</ProcessorArchitecture><Name>Ubuntu</Name><Manufacturer>Canonical Group Limited</Manufacturer><Version>14.04</Version></OperatingSystem></AgentTopologyRequest>"

class AgentTopologyRequestTest < Test::Unit::TestCase
  include FlexMock::TestCase

  TMP_DIR = File.dirname(__FILE__) + "/../tmp/test_agent_topology"
  OS_INFO = "#{TMP_DIR}/os_info"
  VALID_OS_INFO = "OSName=Ubuntu\n OSManufacturer=Canonical Group Limited\n OSVersion=14.04"
  CONF_OMSADMIN = "#{TMP_DIR}/conf_omsadmin"
  PID_FILE = "#{TMP_DIR}/omsagent_pid"
  CONSTANT_PID = "1"
  PROCESS_STATS = "/opt/omi/bin/omicli wql root/scx \"SELECT PercentUserTime, PercentPrivilegedTime, UsedMemory, \
PercentUsedMemory FROM SCX_UnixProcessStatisticalInformation where Handle='#{CONSTANT_PID}'\" | grep ="

  def setup
    FileUtils.mkdir_p(TMP_DIR)
    @fqdn = "abc.xyz.com"
    @entityTypeId = "f2aa1565-ec8c-4d63-8456-7d2bb47dafc5"
    @authcert = 
             "MIIEAzCCAuugAwIBAgIJAM7BHSoGI3jvMA0GCSqGSIb3DQEBCwUAMIGXMS0wKwYD\n" \
             "VQQDDCRjZWM5ZWE2Ni1mNzc1LTQxY2QtYTBhNi0yZDBmMGZmZGFjNmYxLTArBgNV\n" \
             "BAMMJGYyYWExNTY1LWVjOGMtNGQ2My04NDU2LTdkMmJiNDdkYWZjNTEjMCEGA1UE\n" \
             "CwwaTWljcm9zb2Z0IE1vbml0b3JpbmcgQWdlbnQxEjAQBgNVBAoMCU1pY3Jvc29m\n" \
             "dDAeFw0xNTEwMTAwNTUxMTlaFw0xNjEwMDkwNTUxMTlaMIGXMS0wKwYDVQQDDCRj\n" \
             "ZWM5ZWE2Ni1mNzc1LTQxY2QtYTBhNi0yZDBmMGZmZGFjNmYxLTArBgNVBAMMJGYy\n" \
             "YWExNTY1LWVjOGMtNGQ2My04NDU2LTdkMmJiNDdkYWZjNTEjMCEGA1UECwwaTWlj\n" \
             "cm9zb2Z0IE1vbml0b3JpbmcgQWdlbnQxEjAQBgNVBAoMCU1pY3Jvc29mdDCCASIw\n" \
             "DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALm94erWxsNoV/5TCyzgkSceZnfj\n" \
             "FoEolfigtoO3cLryF7GlKb7PDsUtjOz2dqVQ9HVXfLxI29mng3kxGf9FCWIU8OQq\n" \
             "oEtBzhKnQz12PMQXivypC3+h3fWgAVD+oTvK3omZPIu1NNMfjIuRTa0aucWt91Qy\n" \
             "J7Yga4XgUp0RpcduXeYj9AN0TEEglLm7Y5aWMLU23eR3v0Jgz3WfLWBXsVRq+pNd\n" \
             "tqVfNLcFz5AQ1NxFDhbTOoJ08xCkKU+bfgEP+YxTF1cqkeYXcRKAcKzwoO289lO6\n" \
             "n7Gt02s0M3BtHsc8HJHjKLx2SGFevsMKLYGtEMSmqbcCSksew5fqhVcsQ+0CAwEA\n" \
             "AaNQME4wHQYDVR0OBBYEFNcHWcVg1c4ysrvkydceAcV3BJloMB8GA1UdIwQYMBaA\n" \
             "FNcHWcVg1c4ysrvkydceAcV3BJloMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEL\n" \
             "BQADggEBABMA/uxfT4//JyNd5NpwySSRAczC6+IXpOAjHZdj31A0CTOsuzsxT/JC\n" \
             "sPLLXXV3KC60+i3Lfd3Pl2QJAl9f84IdscLYTfVtBkNvCkm0hv4r250L9SpV5QFz\n" \
             "EfimZr8wKZpk8ZRM1J2E9Sdz3eW3vp44GohNH3y2vH7CDVRSE+5lsbi0iTSPWVnL\n" \
             "EbJ+2XtM3lmf5cbvK1eB/pT0JN/o7ttL24eBOR9kcs6GbScIOeimDw6buCX0PMXm\n" \
             "lux69/gTh0mAjeU0ro5rEaxvEus4uyCfzzm1Q+EsZJaIffGyqW791HocM6Ivw5gI\n" \
             "J/rP/YZfFehxmvTHEy60g7OeQuybknk=\n"
  end

  def teardown
    if TMP_DIR
      FileUtils.rm_rf(TMP_DIR)
    end
  end

  def test_invalid_data
    atr = AgentTopologyRequest.new
    os = AgentTopologyRequestOperatingSystem.new
    tm = AgentTopologyRequestOperatingSystemTelemetry.new
 
    # FullyQualfiedDomainName should be type String
    assert_raise ArgumentError do
      atr.FullyQualfiedDomainName = 123
    end

    # EntityTypeId should be type String
    assert_raise ArgumentError do
      atr.EntityTypeId = false
    end
   
    # AuthenticationCertificate should be type String
    assert_raise ArgumentError do
      atr.AuthenticationCertificate = 000 
    end

    # OS_INFO file does not exist
    assert_raise ArgumentError do
      atr.get_telemetry_data(OS_INFO, CONF_OMSADMIN, PID_FILE)
    end
 
    # ProcessorArchitecture should be either "x64" or "x86"
    assert_raise ArgumentError do
      os.ProcessorArchitecture = "64"
    end
 
    # InContainer should be type String
    assert_raise ArgumentError do
      os.InContainer = false
    end
   
    # All Telemetry attributes should be type Integer
    assert_raise ArgumentError do
      tm.PercentUserTime = "0"
    end
  end

  def test_nil_os_info
    flexmock(AgentTopologyRequest).new_instances do |instance|
      instance.should_receive(:`).with(PROCESS_STATS).and_return("PercentUserTime=0\n \
PercentPrivilegedTime=0\n UsedMemory=209576\n PercentUsedMemory=21")
    end

    atr = AgentTopologyRequest.new
    atr.FullyQualfiedDomainName = @fqdn
    atr.EntityTypeId = @entityTypeId
    atr.AuthenticationCertificate = @authcert

    IO.write(OS_INFO, "This is an invalid os_info file")
    IO.write(CONF_OMSADMIN, "This is a test omsadmin.conf file")
    IO.write(PID_FILE, CONSTANT_PID)

    atr.get_telemetry_data(OS_INFO, CONF_OMSADMIN, PID_FILE)
    assert_equal(true, atr.OperatingSystem.nil?)
   
    # convert AgentTopologyRequest object to xml string
    xmlstring = Gyoku.xml({ "AgentTopologyRequest" => {:content! => obj_to_hash(atr)}}) 

    # delete xml generated by Flexmock from the xmlstring
    xmlstring.sub!(/<flexmock_proxy>.*<\/flexmock_proxy>/m, "")

    doc = REXML::Document.new xmlstring
    assert_equal("AgentTopologyRequest", doc.root.name)
    assert_equal(3, doc.root.elements.size)

    assert_equal("FullyQualfiedDomainName", doc.root.elements[1].name)
    assert_equal(@fqdn, doc.root.elements[1].text)

    assert_equal("EntityTypeId", doc.root.elements[2].name)
    assert_equal(@entityTypeId, doc.root.elements[2].text)

    assert_equal("AuthenticationCertificate", doc.root.elements[3].name)
    assert_equal(@authcert, doc.root.elements[3].text)

    flexmock(AgentTopologyRequest).flexmock_teardown
  end 

  def test_nonexistent_pid_file
    atr = AgentTopologyRequest.new
    atr.FullyQualfiedDomainName = @fqdn
    atr.EntityTypeId = @entityTypeId
    atr.AuthenticationCertificate = @authcert

    IO.write(OS_INFO, VALID_OS_INFO)
    IO.write(CONF_OMSADMIN, "This is a test omsadmin.conf file")
    begin
      FileUtils.rm(PID_FILE)
    rescue
    end

    atr.get_telemetry_data(OS_INFO, CONF_OMSADMIN, PID_FILE)
    verify_complete_xml(atr, expect_telemetry = false)

  end

  def test_valid_data
    flexmock(AgentTopologyRequest).new_instances do |instance|
      instance.should_receive(:`).with(PROCESS_STATS).and_return("PercentUserTime=0\n \
PercentPrivilegedTime=0\n UsedMemory=209576\n PercentUsedMemory=21")
    end

    atr = AgentTopologyRequest.new
    atr.FullyQualfiedDomainName = @fqdn
    atr.EntityTypeId = @entityTypeId
    atr.AuthenticationCertificate = @authcert

    IO.write(OS_INFO, VALID_OS_INFO)
    IO.write(CONF_OMSADMIN, "This is a test omsadmin.conf file")
    IO.write(PID_FILE, CONSTANT_PID)

    atr.get_telemetry_data(OS_INFO, CONF_OMSADMIN, PID_FILE)
    assert_equal(false, atr.OperatingSystem.nil?)
    assert_equal(false, atr.OperatingSystem.Telemetry.nil?)    
    verify_complete_xml(atr)

    flexmock(AgentTopologyRequest).flexmock_teardown
  end

  def test_valid_data_empty_process_stats
    flexmock(AgentTopologyRequest).new_instances do |instance|
      #  running PROCESS_STATS on a machine with omsagent not started yet or disabled, return an empty string
      instance.should_receive(:`).with(PROCESS_STATS).and_return("")
    end

    atr = AgentTopologyRequest.new
    atr.FullyQualfiedDomainName = @fqdn
    atr.EntityTypeId = @entityTypeId
    atr.AuthenticationCertificate = @authcert

    IO.write(OS_INFO, VALID_OS_INFO)
    IO.write(CONF_OMSADMIN, "This is a test omsadmin.conf file")
    IO.write(PID_FILE, CONSTANT_PID)

    atr.get_telemetry_data(OS_INFO, CONF_OMSADMIN, PID_FILE)
    verify_complete_xml(atr, expect_telemetry = false)
 
    flexmock(AgentTopologyRequest).flexmock_teardown
  end    

  def verify_complete_xml(atr, expect_telemetry = true)
    # convert AgentTopologyRequest object to xml string
    xmlstring = Gyoku.xml({ "AgentTopologyRequest" => {:content! => obj_to_hash(atr)}})

    # delete any xml generated by Flexmock from the xmlstring
    xmlstring.sub!(/<flexmock_proxy>.*<\/flexmock_proxy>/m, "")

    doc = REXML::Document.new xmlstring

    assert_equal("AgentTopologyRequest", doc.root.name)
    assert_equal(4, doc.root.elements.size)

    assert_equal("FullyQualfiedDomainName", doc.root.elements[1].name)
    assert_equal(@fqdn, doc.root.elements[1].text)

    assert_equal("EntityTypeId", doc.root.elements[2].name)
    assert_equal(@entityTypeId, doc.root.elements[2].text)

    assert_equal("AuthenticationCertificate", doc.root.elements[3].name)
    assert_equal(@authcert, doc.root.elements[3].text)

    assert_equal("OperatingSystem", doc.root.elements[4].name)
    assert_equal(6, doc.root.elements[4].size)

    assert_equal("InContainer", doc.root.elements[4].elements[1].name)
    assert_equal("False", doc.root.elements[4].elements[1].text)

    assert_equal("Telemetry", doc.root.elements[4].elements[2].name)
    if expect_telemetry
      assert_equal("0", doc.root.elements[4].elements[2].attributes["PercentUserTime"])
      assert_equal("0", doc.root.elements[4].elements[2].attributes["PercentPrivilegedTime"])
      assert_equal("209576", doc.root.elements[4].elements[2].attributes["UsedMemory"])
      assert_equal("21", doc.root.elements[4].elements[2].attributes["PercentUsedMemory"])
    else
      assert_equal(true, doc.root.elements[4].elements[2].attributes.empty?)
    end

    assert_equal("ProcessorArchitecture", doc.root.elements[4].elements[3].name)
    assert_equal("x64", doc.root.elements[4].elements[3].text)

    assert_equal("Name", doc.root.elements[4].elements[4].name)
    assert_equal("Ubuntu", doc.root.elements[4].elements[4].text)

    assert_equal("Manufacturer", doc.root.elements[4].elements[5].name)
    assert_equal("Canonical Group Limited", doc.root.elements[4].elements[5].text)

    assert_equal("Version", doc.root.elements[4].elements[6].name)
    assert_equal("14.04", doc.root.elements[4].elements[6].text)
  end

  def test_xml_contains_telemetry_invalid_string
    xmlstring = "this is not an xml string"
    assert_equal(false, xml_contains_telemetry(xmlstring))

    xmlstring = "<?xml version=\"1.0\"?>\n<CertificateUpdateRequest xmlns:xsi=\"" \
                "http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://" \
                "www.w3.org/2001/XMLSchema\" xmlns=\"http://schemas.microsoft.com" \
                "/WorkloadMonitoring/HealthServiceProtocol/2014/09/\">\n</Certifi" \
                "cateUpdateRequest>"
    assert_equal(false, xml_contains_telemetry(xmlstring))
  end

  def test_xml_contains_telemetry_valid_xml_no_telemetry
    xmlstring = "<AgentTopologyRequest><FullyQualfiedDomainName>abc.xyz.com" \
                "</FullyQualfiedDomainName><EntityTypeId>f2aa1565-ec8c-4d63-" \
                "8456-7d2bb47dafc5</EntityTypeId><AuthenticationCertificate>" \
                "MIIEAzCCAuugAwIBAgIJAM7BHSoGI3jvMA0GCSqGSIb3DQEBCwUAMIGXMS0wKwYD\n" \
                "VQQDDCRjZWM5ZWE2Ni1mNzc1LTQxY2QtYTBhNi0yZDBmMGZmZGFjNmYxLTArBgNV\n" \
                "BAMMJGYyYWExNTY1LWVjOGMtNGQ2My04NDU2LTdkMmJiNDdkYWZjNTEjMCEGA1UE\n" \
                "CwwaTWljcm9zb2Z0IE1vbml0b3JpbmcgQWdlbnQxEjAQBgNVBAoMCU1pY3Jvc29m\n" \
                "dDAeFw0xNTEwMTAwNTUxMTlaFw0xNjEwMDkwNTUxMTlaMIGXMS0wKwYDVQQDDCRj\n" \
                "ZWM5ZWE2Ni1mNzc1LTQxY2QtYTBhNi0yZDBmMGZmZGFjNmYxLTArBgNVBAMMJGYy\n" \
                "YWExNTY1LWVjOGMtNGQ2My04NDU2LTdkMmJiNDdkYWZjNTEjMCEGA1UECwwaTWlj\n" \
                "cm9zb2Z0IE1vbml0b3JpbmcgQWdlbnQxEjAQBgNVBAoMCU1pY3Jvc29mdDCCASIw\n" \
                "DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALm94erWxsNoV/5TCyzgkSceZnfj\n" \
                "FoEolfigtoO3cLryF7GlKb7PDsUtjOz2dqVQ9HVXfLxI29mng3kxGf9FCWIU8OQq\n" \
                "oEtBzhKnQz12PMQXivypC3+h3fWgAVD+oTvK3omZPIu1NNMfjIuRTa0aucWt91Qy\n" \
                "J7Yga4XgUp0RpcduXeYj9AN0TEEglLm7Y5aWMLU23eR3v0Jgz3WfLWBXsVRq+pNd\n" \
                "tqVfNLcFz5AQ1NxFDhbTOoJ08xCkKU+bfgEP+YxTF1cqkeYXcRKAcKzwoO289lO6\n" \
                "n7Gt02s0M3BtHsc8HJHjKLx2SGFevsMKLYGtEMSmqbcCSksew5fqhVcsQ+0CAwEA\n" \
                "AaNQME4wHQYDVR0OBBYEFNcHWcVg1c4ysrvkydceAcV3BJloMB8GA1UdIwQYMBaA\n" \
                "FNcHWcVg1c4ysrvkydceAcV3BJloMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEL\n" \
                "BQADggEBABMA/uxfT4//JyNd5NpwySSRAczC6+IXpOAjHZdj31A0CTOsuzsxT/JC\n" \
                "sPLLXXV3KC60+i3Lfd3Pl2QJAl9f84IdscLYTfVtBkNvCkm0hv4r250L9SpV5QFz\n" \
                "EfimZr8wKZpk8ZRM1J2E9Sdz3eW3vp44GohNH3y2vH7CDVRSE+5lsbi0iTSPWVnL\n" \
                "EbJ+2XtM3lmf5cbvK1eB/pT0JN/o7ttL24eBOR9kcs6GbScIOeimDw6buCX0PMXm\n" \
                "lux69/gTh0mAjeU0ro5rEaxvEus4uyCfzzm1Q+EsZJaIffGyqW791HocM6Ivw5gI\n" \
                "J/rP/YZfFehxmvTHEy60g7OeQuybknk=\n" \
                "</AuthenticationCertificate><OperatingSystem><InContainer>False" \
                "</InContainer><Telemetry></Telemetry><ProcessorArchitecture>x64" \
                "</ProcessorArchitecture><Name>Ubuntu</Name><Manufacturer>Canonical " \
                "Group Limited</Manufacturer><Version>14.04</Version>" \
                "</OperatingSystem></AgentTopologyRequest>"
    assert_equal(false, xml_contains_telemetry(xmlstring))
  end

  def test_xml_contains_telemetry_valid_xml_telemetry
    xmlstring = "<AgentTopologyRequest><FullyQualfiedDomainName>abc.xyz.com" \
                "</FullyQualfiedDomainName><EntityTypeId>f2aa1565-ec8c-4d63-" \
                "8456-7d2bb47dafc5</EntityTypeId><AuthenticationCertificate>" \
                "MIIEAzCCAuugAwIBAgIJAM7BHSoGI3jvMA0GCSqGSIb3DQEBCwUAMIGXMS0wKwYD\n" \
                "VQQDDCRjZWM5ZWE2Ni1mNzc1LTQxY2QtYTBhNi0yZDBmMGZmZGFjNmYxLTArBgNV\n" \
                "BAMMJGYyYWExNTY1LWVjOGMtNGQ2My04NDU2LTdkMmJiNDdkYWZjNTEjMCEGA1UE\n" \
                "CwwaTWljcm9zb2Z0IE1vbml0b3JpbmcgQWdlbnQxEjAQBgNVBAoMCU1pY3Jvc29m\n" \
                "dDAeFw0xNTEwMTAwNTUxMTlaFw0xNjEwMDkwNTUxMTlaMIGXMS0wKwYDVQQDDCRj\n" \
                "ZWM5ZWE2Ni1mNzc1LTQxY2QtYTBhNi0yZDBmMGZmZGFjNmYxLTArBgNVBAMMJGYy\n" \
                "YWExNTY1LWVjOGMtNGQ2My04NDU2LTdkMmJiNDdkYWZjNTEjMCEGA1UECwwaTWlj\n" \
                "cm9zb2Z0IE1vbml0b3JpbmcgQWdlbnQxEjAQBgNVBAoMCU1pY3Jvc29mdDCCASIw\n" \
                "DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALm94erWxsNoV/5TCyzgkSceZnfj\n" \
                "FoEolfigtoO3cLryF7GlKb7PDsUtjOz2dqVQ9HVXfLxI29mng3kxGf9FCWIU8OQq\n" \
                "oEtBzhKnQz12PMQXivypC3+h3fWgAVD+oTvK3omZPIu1NNMfjIuRTa0aucWt91Qy\n" \
                "J7Yga4XgUp0RpcduXeYj9AN0TEEglLm7Y5aWMLU23eR3v0Jgz3WfLWBXsVRq+pNd\n" \
                "tqVfNLcFz5AQ1NxFDhbTOoJ08xCkKU+bfgEP+YxTF1cqkeYXcRKAcKzwoO289lO6\n" \
                "n7Gt02s0M3BtHsc8HJHjKLx2SGFevsMKLYGtEMSmqbcCSksew5fqhVcsQ+0CAwEA\n" \
                "AaNQME4wHQYDVR0OBBYEFNcHWcVg1c4ysrvkydceAcV3BJloMB8GA1UdIwQYMBaA\n" \
                "FNcHWcVg1c4ysrvkydceAcV3BJloMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEL\n" \
                "BQADggEBABMA/uxfT4//JyNd5NpwySSRAczC6+IXpOAjHZdj31A0CTOsuzsxT/JC\n" \
                "sPLLXXV3KC60+i3Lfd3Pl2QJAl9f84IdscLYTfVtBkNvCkm0hv4r250L9SpV5QFz\n" \
                "EfimZr8wKZpk8ZRM1J2E9Sdz3eW3vp44GohNH3y2vH7CDVRSE+5lsbi0iTSPWVnL\n" \
                "EbJ+2XtM3lmf5cbvK1eB/pT0JN/o7ttL24eBOR9kcs6GbScIOeimDw6buCX0PMXm\n" \
                "lux69/gTh0mAjeU0ro5rEaxvEus4uyCfzzm1Q+EsZJaIffGyqW791HocM6Ivw5gI\n" \
                "J/rP/YZfFehxmvTHEy60g7OeQuybknk=\n" \
                "</AuthenticationCertificate><OperatingSystem><InContainer>False" \
                "</InContainer><Telemetry PercentUserTime=\"0\" " \
                "PercentPrivilegedTime=\"0\" UsedMemory=\"209576\" PercentUsedMemory" \
                "=\"21\"></Telemetry><ProcessorArchitecture>x64</ProcessorArchitecture>" \
                "<Name>Ubuntu</Name><Manufacturer>Canonical Group Limited" \
                "</Manufacturer><Version>14.04</Version></OperatingSystem>" \
                "</AgentTopologyRequest>"
    assert_equal(true, xml_contains_telemetry(xmlstring))
  end
    
end  

