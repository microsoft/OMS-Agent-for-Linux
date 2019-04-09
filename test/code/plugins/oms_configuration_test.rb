require 'tempfile'
require 'openssl'
require 'json'
require_relative 'omstestlib'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/oms_configuration'

module OMS

  class ConfigurationTest < Test::Unit::TestCase

    TEST_WORKSPACE_ID = '08d4b0c0-7fac-4159-987c-000271282eff'
    TEST_AGENT_GUID = '99f96fba-f08c-483c-be81-6af3fded99c4'
    TEST_CERT_UPDATE_ENDPOINT = 'https://www.fakeoms.com/ConfigurationService.Svc/RenewCertificate'
    TEST_DSC_ENDPOINT = 'https://www.fakedsc.com/Accounts/08d4b0c0-7fac-4159-987c-000271282eff'
    TEST_ODS_ENDPOINT = 'https://www.fakeods.com/OperationalData.svc/PostJsonDataItems'
    TEST_GET_BLOB_ODS_ENDPOINT = 'https://www.fakeods.com/ContainerService.svc/GetBlobUploadUri'
    TEST_NOTIFY_BLOB_ODS_ENDPOINT = 'https://www.fakeods.com/ContainerService.svc/PostBlobUploadNotification'
    TEST_TOPOLOGY_INTERVAL = 7200.0
    TEST_TELEMETRY_INTERVAL = 600.0
    TEST_TOPOLOGY_RESPONSE = '<?xml version="1.0" encoding="utf-8"?>' \
                             '<LinuxAgentTopologyResponse queryInterval="PT2H" telemetryReportInterval="PT10M" ' \
                             'id="ccb89298-086e-4a77-ba5e-5b525156d692" ' \
                             'xmlns="http://schemas.microsoft.com/WorkloadMonitoring/HealthServiceProtocol/2014/09/" ' \
                             'xmlns:xsd="http://www.w3.org/2001/XMLSchema" ' \
                             'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' \
                             '</LinuxAgentTopologyResponse>'
                             # truncated to relevant portion, e.g. containing queryInterval, telemetryReportInterval

    # Extend class to reset class variables
    class OMS::Configuration
      class << self
        def configurationLoaded=(configLoaded)
          @@ConfigurationLoaded = configLoaded
        end
      end
    end

    def setup
      # Reset the states
      Configuration.configurationLoaded = false
      Common.OSFullName = nil
      @tmp_conf_file = Tempfile.new('oms_conf_file')
      @tmp_cert_file = Tempfile.new('temp_cert_file')
      @tmp_key_file = Tempfile.new('temp_key_file')
    end

    def teardown
      [@tmp_conf_file, @tmp_cert_file, @tmp_key_file].each { |tmpfile|
        tmpfile.unlink
      }
    end

    def prepare_files
      conf = "WORKSPACE_ID=#{TEST_WORKSPACE_ID}\n" \
      "AGENT_GUID=#{TEST_AGENT_GUID}\n" \
      "LOG_FACILITY=local0\n" \
      "CERTIFICATE_UPDATE_ENDPOINT=#{TEST_CERT_UPDATE_ENDPOINT}\n" \
      "DSC_ENDPOINT=#{TEST_DSC_ENDPOINT}\n" \
      "OMS_ENDPOINT=#{TEST_ODS_ENDPOINT}\n"

      File.write(@tmp_conf_file.path, conf)

      # this is a fake certificate
      cert = "-----BEGIN CERTIFICATE-----\n" \
             "MIIDzTCCArWgAwIBAgIJAOE3pIATfJnUMA0GCSqGSIb3DQEBCwUAMH0xFzAVBgNV\n" \
             "BAMMDmZha2Utd29ya3NwYWNlMS0wKwYDVQQDDCQyYTg3YjkyZC0yZDdjLTQ0ZmEt\n" \
             "YjM3Ny0zNjZlOWIzNTM3YmMxHzAdBgNVBAsMFkxpbnV4IE1vbml0b3JpbmcgQWdl\n" \
             "bnQxEjAQBgNVBAoMCU1pY3Jvc29mdDAeFw0xNTExMjAyMzQwMjFaFw0xNjExMTky\n" \
             "MzQwMjFaMH0xFzAVBgNVBAMMDmZha2Utd29ya3NwYWNlMS0wKwYDVQQDDCQyYTg3\n" \
             "YjkyZC0yZDdjLTQ0ZmEtYjM3Ny0zNjZlOWIzNTM3YmMxHzAdBgNVBAsMFkxpbnV4\n" \
             "IE1vbml0b3JpbmcgQWdlbnQxEjAQBgNVBAoMCU1pY3Jvc29mdDCCASIwDQYJKoZI\n" \
             "hvcNAQEBBQADggEPADCCAQoCggEBAOT1+CHaw5wiLFTYFP9FudR4Vt8mADpzgt+J\n" \
             "71rfWG7ZZSvNDMMr6LglBXg045mNyUh7N2zAQbMbEyWDs82TD7x59EPRfOfb8pE/\n" \
             "lKPTG9c05b3ANY4yY0fGOPb0SWaHeDn+kBicNWQmfwVlKk98xeGohJCFqwTGMrXV\n" \
             "Pd3zy9p9vrpiQ2yS8bfPbd+NoWnY/EyWmDRhqfUa9rciqJBvnCvebNYnvWl4X0ri\n" \
             "1DY+11eJS4Y4qM+bAm3MG15fqr+B+biToeJGCAfEMRwZFEUdYaNvg6ADQu4vcn6B\n" \
             "q9gZlInCN+yyMOQMWfSqyeGoTOkZVGPcDZeSMmpWgd+doNq54LECAwEAAaNQME4w\n" \
             "HQYDVR0OBBYEFKxFIJKRXiYteAeNeXnq/mFONmEeMB8GA1UdIwQYMBaAFKxFIJKR\n" \
             "XiYteAeNeXnq/mFONmEeMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEB\n" \
             "AGCup0o6x2Kc+KbVycwr+6sYBCY17WJNC6btgAlE7PUzc3X+vtsKjQwdvRnSrlSM\n" \
             "UlxhMdOYN2VjufSGaCSaNsHsXMtHBMjt7C3w3si+e0rBu4LgK6MfEiKmnSvqsb+g\n" \
             "K5JDm2RKGT6oMqKzes5el12b1uw9pB9mbwcD9AGNNIDcgdn7VtVuL9UVDw7uINx5\n" \
             "4phgHLFZDTsbFH6JXwD9Msv6e1vMLZTbGpbbaYfbyTvkeYNzC0zcgEMw7ZeBpYEk\n" \
             "Bn35DO1ax2QdO/nsMNTIkAO67nUtzzIWyC45PVJ+u7YGbkXb5fAdeGtHXyIzHIEn\n" \
             "207V8aTDQntaZeNsLWUnXug=\n" \
             "-----END CERTIFICATE-----"


      File.write(@tmp_cert_file.path, cert)

      # this is a fake key
      key = "-----BEGIN RSA PRIVATE KEY-----\n" \
            "MIIEowIBAAKCAQEA5PX4IdrDnCIsVNgU/0W51HhW3yYAOnOC34nvWt9YbtllK80M\n" \
            "wyvouCUFeDTjmY3JSHs3bMBBsxsTJYOzzZMPvHn0Q9F859vykT+Uo9Mb1zTlvcA1\n" \
            "jjJjR8Y49vRJZod4Of6QGJw1ZCZ/BWUqT3zF4aiEkIWrBMYytdU93fPL2n2+umJD\n" \
            "bJLxt89t342hadj8TJaYNGGp9Rr2tyKokG+cK95s1ie9aXhfSuLUNj7XV4lLhjio\n" \
            "z5sCbcwbXl+qv4H5uJOh4kYIB8QxHBkURR1ho2+DoANC7i9yfoGr2BmUicI37LIw\n" \
            "5AxZ9KrJ4ahM6RlUY9wNl5IyalaB352g2rngsQIDAQABAoIBAGWLmZMaPSsgFN1E\n" \
            "QHu+5t4OySiK6AsEdATEXj3FVKlFDZPRi1l8Peh9suFPQ6o0shLNYxV+ZyUSWvmG\n" \
            "YdZI5O/IfscdP/JtIDW/JyNJW82kjkgL2TTJsDKC/Xy5d1xbtLyz5CCmFx/l2uv/\n" \
            "pDZAtlqQrMqUHfcuGAuBGcE4gS7TQzt4x8eHtCYlriBebnyJA+Mn8L7rM3oOT0Nh\n" \
            "2Oy/TgH49xY2ODbja7hn6RbsA11Jn2byUVPaopcNOPTmtPBVWoliDFRan+Q+dPfm\n" \
            "InbExJQrCZCcc3/mijye8j6b9RCsoZ7JKzsFaLzU7RSHt3LPaQzbAyQ/KtZ/xBg8\n" \
            "KP1gj2ECgYEA+8EQHqkX4yGdADBcLFR+Ai0hcmKq9gpyBO796R5Mm+lhDni6sH6z\n" \
            "m+tpqDd+HICj+NJqAf5zetBQUexi8Xi7y8aZezyxknaXgr4r8EFSNywyGRpo99ii\n" \
            "FTALq8t/pyM1BS6tStI5+NQWJL0f0rFrOl/Y+MZ7emiQfbakGQ1MmmUCgYEA6NJ/\n" \
            "Qy6ew/z3AqeYnxG7JtQVjTHN7wERdfNTcVXYSe6vqv9wIRyfXGoQML5uM140x1Oq\n" \
            "pNw3jjk83aGNByTBwBvTT+7Zqq/AUe/7GzMGw3HM26qqKdvqUWx3dGIV4zaoqFP8\n" \
            "rB1EFj5RX7V2hx/taVWEN677tI6r1cMNNp5dAl0CgYEAjSAi6y0bCOYU3sA9S1Rp\n" \
            "9spZz4dkEty0IfPfPkkP5O6ky7n93WaJRMRozDWfalbqlFdPuaJsFdKk0+fRZ0+o\n" \
            "5oiEDUNuv43fTRlSBDJ55hfOVagqY5V69qmiQUGoY4cm96q81g6XFNe/OgUSy8dN\n" \
            "NsH4HS0Wlv360Z4Ky0hbQskCgYA7rrow3qKUWyR26b+WB1WSfouHxlykCAIR2m5p\n" \
            "fzgSu70MeK6lzlCLwCSmWiqlwGCHOEtmN42GR+XyapdcXW/Nb1ScCP6DYspKNtqH\n" \
            "/mydbW62YOl+EYHfnY6BpyM1O63AeMcs19O8X/08K6hWuziA6Ascux6LCofCJF4e\n" \
            "wjnVgQKBgHaH990opFVun6+RDi6MZabRHRxfNEHTxTRK2x+9qDiZu/kAlUdlTWSt\n" \
            "baBu6DoyHxNsyNg/39rA+8PYQBgbMOfO7t4TGv2FTT8kVlNdVCEVvPVNfFEnlqOu\n" \
            "pMbKdhdK/zhvgRUpKON8rnw/vnpKEs5qQi3LHyp/WooEw9VqZcoW\n" \
            "-----END RSA PRIVATE KEY-----"


      File.write(@tmp_key_file.path, key)
    end

    def test_load_configuration()
      prepare_files
      $log = MockLog.new
      success = Configuration.load_configuration(@tmp_conf_file.path, @tmp_cert_file.path, @tmp_key_file.path)
      puts $log.logs
      assert_equal(true, success, "Configuration should be loaded")
      assert_equal(TEST_WORKSPACE_ID, Configuration.workspace_id, "Workspace ID should be loaded")
      assert_equal(TEST_AGENT_GUID, Configuration.agent_id, "Agent ID should be loaded")
      assert_equal(TEST_ODS_ENDPOINT, Configuration.ods_endpoint.to_s, "ODS Endpoint should be loaded")
      assert_equal(TEST_GET_BLOB_ODS_ENDPOINT, Configuration.get_blob_ods_endpoint.to_s, "GetBlob ODS Endpoint should be loaded")
      assert_equal(TEST_NOTIFY_BLOB_ODS_ENDPOINT, Configuration.notify_blob_ods_endpoint.to_s, "NotifyBlobUpload ODS Endpoint should be loaded")
      assert_not_equal(nil, Configuration.cert, "Certificate should be loaded")
      assert_not_equal(nil, Configuration.key, "Key should be loaded")
      assert_equal(["Azure region value is not set. This must be onpremise machine"], $log.logs, "There was an error loading the configuration")
      Configuration.set_request_intervals(TEST_TOPOLOGY_INTERVAL, TEST_TELEMETRY_INTERVAL)
      assert_equal(TEST_TOPOLOGY_INTERVAL, Configuration.topology_interval, "Incorrect topology interval parsed")
      assert_equal(TEST_TELEMETRY_INTERVAL, Configuration.telemetry_interval, "Incorrect telemetry interval parsed")
    end

    def test_load_configuration_wrong_path()
      prepare_files
      fake_conf_path = @tmp_conf_file.path + '.fake'
      assert_equal(false, File.file?(fake_conf_path))
      success = Configuration.load_configuration(fake_conf_path, @tmp_cert_file.path, @tmp_key_file.path)
      assert_equal(false, success, "Should not find configuration in a non existing file")
      
      fake_cert_path = @tmp_cert_file.path + '.fake'
      assert_equal(false, File.file?(fake_cert_path))
      success = Configuration.load_configuration(@tmp_conf_file.path, fake_cert_path, @tmp_key_file.path)
      assert_equal(false, success, "Should not find configuration in a non existing file")

      fake_key_path = @tmp_key_file.path + '.fake'
      assert_equal(false, File.file?(fake_key_path))
      success = Configuration.load_configuration(@tmp_key_file.path, @tmp_cert_file.path, fake_key_path)
      assert_equal(false, success, "Should not find configuration in a non existing file")

      $log = MockLog.new
      # Should retry the second time since it did not find anything before
      success = Configuration.load_configuration(@tmp_conf_file.path, @tmp_cert_file.path, @tmp_key_file.path)
      assert_equal(true, success, 'Configuration should be loaded')
      assert_equal(["Azure region value is not set. This must be onpremise machine"], $log.logs, "There was an error loading the configuration")
    end

    def test_parse_proxy_config()
      configs = ["http://proxyuser:proxypass@proxyhost:8080",
                 "proxyuser:proxypass@proxyhost:8080",
                 "http://proxyhost:8080",
                 "http://proxyuser:proxypass@proxyhost",
                 "proxyhost:8080",
                 "http://proxyhost",
                 "proxyuser:proxypass@proxyhost",
                 "proxyhost",
                 "https://1.2.3.4:1234",
                 "proxyuser:pass:pass@proxyhost:8080",
                 "123.2.3.456:3456"]
      
      expected = [{:user=>"proxyuser", :pass=>"proxypass", :addr=>"proxyhost", :port=>"8080"},
                  {:user=>"proxyuser", :pass=>"proxypass", :addr=>"proxyhost", :port=>"8080"},
                  {:user=>nil,         :pass=>nil,         :addr=>"proxyhost", :port=>"8080"},
                  {:user=>"proxyuser", :pass=>"proxypass", :addr=>"proxyhost", :port=>nil},
                  {:user=>nil,         :pass=>nil,         :addr=>"proxyhost", :port=>"8080"},
                  {:user=>nil,         :pass=>nil,         :addr=>"proxyhost", :port=>nil},
                  {:user=>"proxyuser", :pass=>"proxypass", :addr=>"proxyhost", :port=>nil},
                  {:user=>nil,         :pass=>nil,         :addr=>"proxyhost", :port=>nil},
                  {:user=>nil,         :pass=>nil,         :addr=>"1.2.3.4",   :port=>"1234"},
                  {:user=>"proxyuser", :pass=>"pass:pass", :addr=>"proxyhost", :port=>"8080"},
                  {:user=>nil,         :pass=>nil,         :addr=>"123.2.3.456",:port=>"3456"}]
      
      assert_equal(configs.size, expected.size, "Test array and result array should have the same size")
      
      expected.zip(configs).each { |expect, config|
        parsed = Configuration.parse_proxy_config(config)
        assert_equal(expect, parsed, "Parsing failed for this partial configuration : '#{config}'")
      }
    end

    def test_parse_proxy_config_failure()
      bad_configs = [ "http://proxyuser:proxypass@proxyhost:",    # Missing port
                      "http://proxyuser:proxypass/proxyhost:8080",# Wrong '@' separator
                      "http://proxyuserandpass@proxyhost:8080",   # Missing ':' separator
                      "socks://proxyuser:proxypass@proxyhost:8080"] # Unsupported protocol
      bad_configs.each { |config|
        parsed = Configuration.parse_proxy_config(config)
        assert_equal(nil, parsed, "Parsing should have failed for '#{config}'")
      }
    end

    def test_get_proxy_config_failure()
      config = Configuration.get_proxy_config("fake_file_path")
      assert_equal({}, config, "Config should have failed to load anything.")
    end

    def test_get_proxy_config_success()
      @tmp_conf_file = Tempfile.new('proxy.conf')
      config = "http://proxyconfig:proxypass@proxyhost:8080"
      expected = {:user=>"proxyconfig", :pass=>"proxypass", :addr=>"proxyhost", :port=>"8080"}

      File.write(@tmp_conf_file.path, config)
      parsed = Configuration.get_proxy_config(@tmp_conf_file.path)
      assert_equal(expected, parsed, "Failed to load expected config")
    end
  end
end # Module OMS
