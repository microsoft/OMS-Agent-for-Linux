require 'tempfile'
require 'openssl'
require 'net/http'
require 'net/https'
require 'json'
require 'fileutils'
require 'flexmock/test_unit'
require 'syslog/logger'
require_relative 'omstestlib'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/oms_common'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/agent_common'

module OMS

  TestHostnameList = 
  [
          #         Address Type  Compliant Name

    TestHostname.new(:RFC1123Hostname, true,  'onetwo'),
    TestHostname.new(:RFC1123Hostname, true,  'xxx1234'),
    TestHostname.new(:RFC1123Hostname, true,  'x'),
    TestHostname.new(:RFC1123Hostname, true,  'www'),
    TestHostname.new(:RFC1123Hostname, true,  'Microsoft'),
    TestHostname.new(:RFC1123Hostname, true,  'xxx123456789012345678901234567890123456789012345678901234567890'),

    TestHostname.new(:RFC1123Hostname, false, ''),
    TestHostname.new(:RFC1123Hostname, false, 'xxx123456789012345678901234567890123456789012345678901234567890x'),
    TestHostname.new(:RFC1123Hostname, false, 'one.two'),
    TestHostname.new(:RFC1123Hostname, false, 'one:two'),
    TestHostname.new(:RFC1123Hostname, false, 'microsoft.com'),
    TestHostname.new(:RFC1123Hostname, false, 'microsoft:355'),
    TestHostname.new(:RFC1123Hostname, false, nil),

    TestHostname.new(:IPv4,            true,  '192.168.0.5'),
    TestHostname.new(:IPv4,            true,  '1.2.3.4'),
    TestHostname.new(:IPv4,            true,  '254.254.254.254'),
    TestHostname.new(:IPv4,            true,  '1.0.0.0'),

    TestHostname.new(:IPv4,            false, ''),
    TestHostname.new(:IPv4,            false, '192.168.0.256'),
    TestHostname.new(:IPv4,            false, '1.0.0.444'),
    TestHostname.new(:IPv4,            false, '192.168.0.A'),
    TestHostname.new(:IPv4,            false, '0.2.3.4'),
    TestHostname.new(:IPv4,            false, '1.2.3.255'),
    TestHostname.new(:IPv4,            false, '255.255.255.255'),
    TestHostname.new(:IPv4,            false, '192.168.0'),
    TestHostname.new(:IPv4,            false, '192.168..5'),
    TestHostname.new(:IPv4,            false, '192.168.0.5.5'),
    TestHostname.new(:IPv4,            false, '192.168.0.5.A'),

    TestHostname.new(:IPv6,            true,  '2001:0db8:85a3:0000:0000:8a2e:0370:7334'),
    TestHostname.new(:IPv6,            true,  '1234:DDDD:FFFF:EEEE:3333:8888:7777:1111'),
    TestHostname.new(:IPv6,            true,  '0db8:85a3:0000:0000:8a2e:0370:7334:f135'),

    TestHostname.new(:IPv6,            false, ''),
    TestHostname.new(:IPv6,            false, '1000:::::::1000'),
    TestHostname.new(:IPv6,            false, 'XXXX:0db8:85a3:0000:0000:8a2e:0370:7334'),
    TestHostname.new(:IPv6,            false, 'xx:0db8:85a3:0000:0000:8a2e:0370:7334'),
    TestHostname.new(:IPv6,            false, ':0db8:85a3:0000:0000:8a2e:0370:7334'),
    TestHostname.new(:IPv6,            false, '0db8:85a3:0000:0000:8a2e:0370:7334'),
    TestHostname.new(:IPv6,            false, ':0db8:85a3:0000:0000:8a2e:0370:7334'),
  ]

  class CommonTest < Test::Unit::TestCase
    include FlexMock::TestCase

    # Extend class to reset OSFullName class variable
    class OMS::Common
      class << self
        def OSFullName=(os_full_name)
          @@OSFullName = os_full_name
        end

        def OSName=(os_name)
          @@OSName = os_name
        end

        def OSVersion=(os_version)
          @@OSVersion = os_version
        end
      
        def InstalledDate=(installed_date)
          @@InstalledDate = installed_date
        end

        def AgentVersion=(agent_version)
          @@AgentVersion = agent_version
        end

        def CurrentTimeZone=(timezone)
          @@CurrentTimeZone = timezone
        end

        def tzLocalTimePath=(localtimepath)
          @@tzLocalTimePath = localtimepath
        end

        def Hostname=(hostname)
          @@Hostname = hostname
        end

        def HostnameFilePath=(hostname_file_path)
          @@HostnameFilePath = hostname_file_path
        end

        def GetHostnameInternalForTest
          return @@Hostname
        end
      end
    end

    class OMS::Configuration
      class << self
        def cert=(mock_cert)
          @@Cert = mock_cert
        end
        
        def key=(mock_key)
          @@Key = mock_key
        end
      end
    end

    def setup
      @tmp_conf_file = Tempfile.new('oms_conf_file')
      @tmp_localtime_file = Tempfile.new('oms_localtime_file')
      # Reset the OS name between tests
      Common.OSFullName = nil
      Common.OSName = nil
      Common.OSVersion = nil
      Common.InstalledDate = nil
      Common.AgentVersion = nil
      Common.CurrentTimeZone = nil
      Common.tzLocalTimePath = '/etc/localtime'
    end

    def teardown
      tmp_path = @tmp_conf_file.path
      assert_equal(true, File.file?(tmp_path))
      @tmp_conf_file.unlink
      assert_equal(false, File.file?(tmp_path))
      tmp_path = @tmp_localtime_file.path
      assert_equal(true, File.file?(tmp_path))
      @tmp_localtime_file.unlink
      assert_equal(false, File.file?(tmp_path))
    end

     @@OSConf = "OSName=CentOS Linux\n" \
      "OSVersion=7.0\n" \
      "OSFullName=CentOS Linux 7.0 (x86_64)\n" \
      "OSAlias=UniversalR\n" \
      "OSManufacturer=Central Logistics GmbH\n"

    # Begin:  Tests on Public internals; probably only for use inside the Singular object.

    def test_clean_hostname_string
      hostname = '        microsoft     '
      b = Common.clean_hostname_string(hostname)
      expected = 'microsoft'
      assert_equal(b, expected, "method clean_hostname_string should return '#{expected}'.")
      hostname = expected
      b = Common.clean_hostname_string(hostname)
      assert_equal(b, expected, "method clean_hostname_string should return '#{expected}'.")
    end

    def test_has_designated_hostnamefile?
      container_hostname_tempfile = Tempfile.new('containerhostname')
      test_hostname = 'test_hostname'
      Common.HostnameFilePath = container_hostname_tempfile.path
      File.write(container_hostname_tempfile.path, test_hostname)
      r = Common.has_designated_hostnamefile?
      assert(r, "method has_designated_hostnamefile? should see #{container_hostname_tempfile.path} exists at this point.")
      container_hostname_tempfile.unlink
      r = Common.has_designated_hostnamefile?
      assert_false(r, "method has_designated_hostnamefile? should see #{container_hostname_tempfile.path} Does NOT exist at this point.")
      Common.HostnameFilePath = nil
      Common.Hostname = nil
    end

    def test_is_hostname_compliant?
      TestHostnameList.each do |thno| # thno stands for TestHostname object
        next unless thno.AddressType == :RFC1123Hostname
        if thno.SpecCompliant then
          assert(Common.is_hostname_compliant?(thno.Hostname),       "Common.is_hostname_compliant?(#{thno.Hostname}) should be true.")
        else
          assert_false(Common.is_hostname_compliant?(thno.Hostname), "Common.is_hostname_compliant?(#{thno.Hostname}) should NOT be true.")
        end
      end
    end

    def test_is_like_ipv4_string?
      TestHostnameList.each do |thno| # thno stands for TestHostname object
        next unless thno.AddressType == :IPv4
        if thno.SpecCompliant then
          assert(Common.is_like_ipv4_string?(thno.Hostname),       "Common.is_like_ipv4_string?(#{thno.Hostname}) should be true.")
        else
          assert_false(Common.is_like_ipv4_string?(thno.Hostname), "Common.is_like_ipv4_string?(#{thno.Hostname}) should NOT be true.")
        end
      end
    end

    def test_is_like_ipv6_string?
      TestHostnameList.each do |thno| # thno stands for TestHostname object
        next unless thno.AddressType == :IPv6
        if thno.SpecCompliant then
          assert(Common.is_like_ipv6_string?(thno.Hostname),       "Common.is_like_ipv6_string?(#{thno.Hostname}) should be true.")
        else
          assert_false(Common.is_like_ipv6_string?(thno.Hostname), "Common.is_like_ipv6_string?(#{thno.Hostname}) should NOT be true.")
        end
      end
    end

    def test_look_for_socket_class_host_address
      Common.Hostname = nil
      Common.look_for_socket_class_host_address
      hostname = Common.GetHostnameInternalForTest
      assert(hostname.length > 0, "Hostname internal should be non-zero length.")
    end

    def test_look_in_designated_hostnamefile
      container_hostname_tempfile = Tempfile.new('containerhostname')
      test_hostname = 'test_hostname'
      Common.HostnameFilePath = container_hostname_tempfile.path
      File.write(container_hostname_tempfile.path, test_hostname)
      Common.Hostname = nil

      Common.look_in_designated_hostnamefile
      hostname = Common.GetHostnameInternalForTest
      assert_equal(test_hostname, hostname, "Hostname internal should be #{test_hostname} file")

      # Remove container host name file
      container_hostname_tempfile.unlink
      Common.Hostname = nil
      Common.HostnameFilePath = nil
    end

    def test_validate_hostname_equivalent
      TestHostnameList.each do |thno| # thno stands for TestHostname object
        next unless thno.AddressType == :IPv6
        if thno.SpecCompliant then
          assert_nothing_raised do
              Common.validate_hostname_equivalent(thno.Hostname)
          end
        else
          assert_raise NameError do
              Common.validate_hostname_equivalent(thno.Hostname)
          end
        end
      end
    end

    # End:  Tests on Public Internals

    def test_get_os_full_name()
      File.write(@tmp_conf_file.path, @@OSConf)
      os_full_name = Common.get_os_full_name(@tmp_conf_file.path)
      assert_equal('CentOS Linux 7.0 (x86_64)', os_full_name, 'Did not extract the full os name correctly')

      os_full_name_2 = Common.get_os_full_name()
      assert_equal(os_full_name, os_full_name_2, "Getting the os full name a second time should return the cached result")
    end

    def test_get_os_name()
      File.write(@tmp_conf_file.path, @@OSConf)
      os_name = Common.get_os_name(@tmp_conf_file.path)
      assert_equal('CentOS Linux', os_name, 'Did not extract the os name correctly')

      os_name_2 = Common.get_os_name()
      assert_equal(os_name, os_name_2, "Getting the os name a second time should return the cached result")
    end

    def test_get_os_version()
      File.write(@tmp_conf_file.path, @@OSConf)
      os_version = Common.get_os_version(@tmp_conf_file.path)
      assert_equal('7.0', os_version, 'Did not extract the os version correctly')

      os_version_2 = Common.get_os_version()
      assert_equal(os_version, os_version_2, "Getting the os version a second time should return the cached result")
    end

    def test_get_os_full_name_wrong_path()
      fake_conf_path = @tmp_conf_file.path + '.fake'
      assert_equal(false, File.file?(fake_conf_path))
      os_full_name = Common.get_os_full_name(fake_conf_path)
      assert_equal(nil, os_full_name, "Should not find data in a non existing file")
      
      # Should retry the second time since it did not find anything before
      File.write(@tmp_conf_file.path, "OSFullName=Ubuntu 14.04 (x86_64)\n")
      os_full_name = Common.get_os_full_name(@tmp_conf_file.path)
      assert_equal('Ubuntu 14.04 (x86_64)', os_full_name, 'Did not extract the full os name correctly')
    end

    def test_get_os_name_wrong_path()
      fake_conf_path = @tmp_conf_file.path + '.fake'
      assert_equal(false, File.file?(fake_conf_path))
      os_name = Common.get_os_name(fake_conf_path)
      assert_equal(nil, os_name, "Should not find data in a non existing file")

      # Should retry the second time since it did not find anything before
      File.write(@tmp_conf_file.path, "OSName=Ubuntu\n")
      os_name = Common.get_os_name(@tmp_conf_file.path)
      assert_equal('Ubuntu', os_name, 'Did not extract the os name correctly')
    end

    def test_get_os_version_wrong_path()
      fake_conf_path = @tmp_conf_file.path + '.fake'
      assert_equal(false, File.file?(fake_conf_path))
      os_version = Common.get_os_version(fake_conf_path)
      assert_equal(nil, os_version, "Should not find data in a non existing file")

      # Should retry the second time since it did not find anything before
      File.write(@tmp_conf_file.path, "OSVersion=14.04\n")
      os_version = Common.get_os_version(@tmp_conf_file.path)
      assert_equal('14.04', os_version, 'Did not extract the os version correctly')
    end

    def test_get_os_full_name_missing_field()
      conf = @@OSConf.gsub(/OSFullName=.*\n/, "")
      File.write(@tmp_conf_file.path, conf)
      os_full_name = Common.get_os_full_name(@tmp_conf_file.path)
      assert_equal(nil, os_full_name, "Should not find data when field is missing")
    end

    def test_get_os_name_missing_field()
      conf = @@OSConf.gsub(/OSName=.*\n/, "")
      File.write(@tmp_conf_file.path, conf)
      os_name = Common.get_os_name(@tmp_conf_file.path)
      assert_equal(nil, os_name, "Should not find data when field is missing")
    end

    def test_get_os_version_missing_field()
      conf = @@OSConf.gsub(/OSVersion=.*\n/, "")
      File.write(@tmp_conf_file.path, conf)
      os_version = Common.get_os_version(@tmp_conf_file.path)
      assert_equal(nil, os_version, "Should not find data when field is missing")
    end

    def test_get_hostname
      $log = MockLog.new
      hostname = Common.get_hostname
      assert_equal([], $log.logs, "There was an error parsing the hostname")
      # Sanity check
      assert_not_equal(nil, hostname, "Could not get the hostname")
      assert(hostname.size > 0, "Hostname returned is empty")
    end

    def test_get_hostname_in_containerized_agent
      $log = MockLog.new

      # create container hostname file
      # get_hostname should read hostname from this file when exist
      container_hostname_tempfile = Tempfile.new('containerhostname')
      test_hostname = 'test_hostname'
      Common.Hostname = nil
      Common.HostnameFilePath = container_hostname_tempfile.path
      File.write(container_hostname_tempfile.path, test_hostname)
      hostname = Common.get_hostname
      assert_equal(test_hostname, hostname, 'get_hostname should read from containerhostname file')

      # Remove container host name file
      # get_hostname should get hostname from Socket.gethostname when this file when doesn't exist
      Common.Hostname = nil
      container_hostname_tempfile.unlink
      hostname = Common.get_hostname
      test_hostname = Socket.gethostname
      assert_equal(test_hostname, hostname, 'get_hostname should read from Socket.gethostname')
    end

    def test_get_hostname_as_mocks_from_socket_gethostname
      result_hostname = nil
      TestHostnameList.each do |thno| # thno stands for TestHostname object
        $log = MockLog.new
        flexmock(Socket, :strict, Socket => :gethostname, :gethostname => thno.Hostname) do
          load "#{ENV['BASE_DIR']}/source/code/plugins/oms_common.rb"
          assert_nothing_raised do
            result_hostname = Common.get_hostname
          end
          if thno.Hostname.nil? then
              assert_equal(result_hostname, '', 'Did not get correct hostname')
          else
              assert_equal(result_hostname, thno.Hostname, 'Did not get correct hostname')
          end
          if thno.SpecCompliant then
            assert($log.logs.empty?, "No exception should be logged")
          else
            assert_false($log.logs.empty?, "Error should be logged")
            # Checks on error logs for the validation specifics may be appropriate, but leaving
            # out for now until there is a task specifying the log text so we don't generate
            # unknown issues.
            assert($log.logs[-1].include?('did NOT validate as compliant.'), "Warning in log: #{$log.logs}")
          end
        end
        flexmock(Socket).flexmock_teardown
        sleep 0.1
      end
      # Then back to normal (a validation afterwards would be better, but that is another project)
      flexmock(Socket).flexmock_teardown
      load "#{ENV['BASE_DIR']}/source/code/plugins/oms_common.rb"
    end

    def test_get_fqdn
      $log = MockLog.new
      fqdn = Common.get_fully_qualified_domain_name
      assert_equal([], $log.logs, "There was an error getting the fqdn")
      # Sanity check
      assert_not_equal(nil, fqdn, "Could not get the fqdn")
      assert(fqdn.size > 0, "Fqdn returned is empty")
    end

    @@InstallConf = "1.1.0-124 20160412 Release_Build\n" \
      "2016-05-24T00:27:55.0Z\n" 

    def test_get_agent_version()
      File.write(@tmp_conf_file.path, @@InstallConf)
      agent_version = Common.get_agent_version(@tmp_conf_file.path)
      assert_equal('1.1.0-124', agent_version, 'Did not extract the agent version correctly')

      agent_version_2 = Common.get_agent_version()
      assert_equal(agent_version, agent_version_2, "Getting the agent version a second time should return the cached result")
    end

    def test_get_agent_version_wrong_path()
      fake_conf_path = @tmp_conf_file.path + '.fake'
      assert_equal(false, File.file?(fake_conf_path))
      agent_version = Common.get_agent_version(fake_conf_path)
      assert_equal(nil, agent_version, "Should not find data in a non existing file")

      # Should retry the second time since it did not find anything before
      File.write(@tmp_conf_file.path, "1.1.0-124 20160412\n2016-05-24T00:27:55.0Z")
      agent_version = Common.get_agent_version(@tmp_conf_file.path)
      assert_equal('1.1.0-124', agent_version, 'Did not extract the agent version correctly')
    end

    def test_get_agent_version_missing()
      conf = "  "
      File.write(@tmp_conf_file.path, conf)
      agent_version = Common.get_agent_version(@tmp_conf_file.path)
      assert_equal(nil, agent_version, "Should not find data when line is missing")
    end

    def test_get_installed_date()
      File.write(@tmp_conf_file.path, @@InstallConf)
      installed_date = Common.get_installed_date(@tmp_conf_file.path)
      assert_equal('2016-05-24T00:27:55.0Z', installed_date, 'Did not extract the installed date correctly')

      installed_date_2 = Common.get_installed_date()
      assert_equal(installed_date, installed_date_2, "Getting the installed date a second time should return the cached result")
    end

    def test_get_installed_date_wrong_path()
      fake_conf_path = @tmp_conf_file.path + '.fake'
      assert_equal(false, File.file?(fake_conf_path))
      installed_date = Common.get_installed_date(fake_conf_path)
      assert_equal(nil, installed_date, "Should not find data in a non existing file")

      # Should retry the second time since it did not find anything before
      File.write(@tmp_conf_file.path, "Version\n2016-05-24T00:27:55.0Z")
      installed_date = Common.get_installed_date(@tmp_conf_file.path)
      assert_equal('2016-05-24T00:27:55.0Z', installed_date, 'Did not extract the installed date correctly')
    end

    def test_get_installed_date_missing_line()
      conf = "1.1.0-124 20160412 Release_Build"
      File.write(@tmp_conf_file.path, conf)
      installed_date = Common.get_installed_date(@tmp_conf_file.path)
      assert_equal(nil, installed_date, "Should not find data when line is missing")
    end

    def test_format_time
      formatted_time = Common.format_time(1446682353)
      assert_equal("2015-11-05T00:12:33.000Z", formatted_time, "The time is not in the correct iso8601 format with millisecond precision.")
      formatted_time = Common.format_time(1447984563.078218)
      assert_equal("2015-11-20T01:56:03.078Z", formatted_time, "The time is not in the correct iso8601 format with millisecond precision.")
    end

    def test_file_exists_nonempty
      assert_equal(false, Common.file_exists_nonempty(nil), "should detect nil file path")
      assert_equal(false, Common.file_exists_nonempty("/dev/null/impossible"), "should detect nonexistent file path")
      assert_equal(true, Common.file_exists_nonempty("/"), "file does exist")
    end

    def test_get_logger
      assert_equal(Syslog::LOG_LOCAL0, Common.get_logger(nil).facility, "default log facility should be local0")
      Syslog.close
      assert_equal(Syslog::LOG_USER, Common.get_logger("user").facility, "correct log facility not parsed")
    end

    def test_create_error_tag
      assert_equal("ERROR::xyzzy::", Common.create_error_tag("xyzzy"))
      assert_equal("ERROR::123::", Common.create_error_tag(123))
      assert_equal("ERROR::::", Common.create_error_tag(nil))
    end

    def test_create_secure_http
      uri = URI.parse('https://www.microsoft.com')
      http = Common.create_secure_http(uri)
      assert_not_equal(nil, http, "http is nil")
      assert_equal(true, http.use_ssl?, "Http should use ssl")
    end

    def test_create_ods_http
      uri = URI.parse('https://www.microsoft.com')
      mock_cert = "this is a mock cert"
      mock_key = "this is a mock key"
      Configuration.cert = mock_cert
      Configuration.key = mock_key

      http = Common.create_ods_http(uri)
      assert_not_equal(nil, http, "http is nil")
      assert_equal(true, http.use_ssl?, "http should use ssl")
    end

    def test_form_post_request_and_http
      headers = {}
      headers["User-Agent"] = "LinuxMonitoringAgent/0.0.0-0"
      uri = "https://www.microsoft.com"
      body = { mock: "data", foo: "bar" }.to_json
      cert = "this is a mock cert"
      key = "this is a mock key"
      proxy = ""

      req, http = Common.form_post_request_and_http(headers, uri, body, cert, key, proxy)
      assert_not_equal(nil, http, "http is nil")
      assert_not_equal(nil, req, "request is nil")
      assert_equal('{"mock":"data","foo":"bar"}', req.body, "request body is incorrect")
      assert_equal("LinuxMonitoringAgent/0.0.0-0", req["User-Agent"], "request headers are incorrect")
      assert_equal(cert, http.cert, "http cert is incorrect")
      assert_equal(key, http.key, "http key is incorrect")
    end

    def test_parse_json_record_encoding
      record = "syslog record"
      parsed_record = Common.parse_json_record_encoding(record);
      assert_equal(record.to_json, parsed_record, "parse json record no encoding failed");

      record = {}
      record["DataItems"] = [ {"Message" => "German: Grüß dich"} ];
      parsed_record = Common.parse_json_record_encoding(record);
      assert_equal("{\"DataItems\":[{\"Message\":\"German: Grüß dich\"}]}", parsed_record, "parse json record utf-8 encoding failed");

      record = {}
      record["DataItems"] = [ {"Message" => "Russian: Здравствуйте"} ];
      parsed_record = Common.parse_json_record_encoding(record);
      assert_equal("{\"DataItems\":[{\"Message\":\"Russian: Здравствуйте\"}]}", parsed_record, "parse json record utf-8 encoding failed");

      record = {}
      record["DataItems"] = [ {"Message" => "Greek: Καλημέρα"} ];
      parsed_record = Common.parse_json_record_encoding(record);
      assert_equal("{\"DataItems\":[{\"Message\":\"Greek: Καλημέρα\"}]}", parsed_record, "parse json record utf-8 encoding failed");

      record = {}
      record["DataItems"] = [ {"Message" => "Japanese: おはようございます。"} ];
      parsed_record = Common.parse_json_record_encoding(record);
      assert_equal("{\"DataItems\":[{\"Message\":\"Japanese: おはようございます。\"}]}", parsed_record, "parse json record utf-8 encoding failed");

      record = {}
      record["DataItems"] = [ {"Message" => "iPhone\u00AE"} ];
      parsed_record = Common.parse_json_record_encoding(record);
      assert_equal("{\"DataItems\":[{\"Message\":\"iPhone®\"}]}", parsed_record, "parse json record utf-8 encoding failed");
    end
    
    def test_safe_dump_simple_hash_array_noerror
      $log = MockLog.new

      records = [ { "ID" => 1, "Enabled" => true, "Nil" => nil, "Float" => 1.2, "Message" => "iPhone®" } ];
      json = Common.safe_dump_simple_hash_array(records);
      assert_equal("[{\"ID\":1,\"Enabled\":true,\"Nil\":null,\"Float\":1.2,\"Message\":\"iPhone®\"}]", json, "parse json record utf-8 encoding failed: #{json}");

      assert($log.logs.empty?, "No exception should be logged")
    end
    
    def test_safe_dump_simple_hash_array_firsterror_encoding_success
      $log = MockLog.new

      records = [ { "ID" => 1, "Message" => "iPhone\xAE" } ];
      json = Common.safe_dump_simple_hash_array(records);
      assert_equal("[{\"ID\":1,\"Message\":\"iPhone®\"}]", json, "parse json record utf-8 encoding failed: #{json}");
      assert_not_equal(0, $log.logs.length, "Exception should be logged")
      assert($log.logs[-1].include?("source sequence is illegal/malformed utf-8"), "Except error in log: '#{$log.logs}'")
    end

    def test_safe_dump_simple_hash_array_firsterror_encoding_error
      $log = MockLog.new

      json = nil
      records = [ { "ID" => 1, "Message\xAE" => "iPhone\xAE" } ];
      assert_nothing_raised(RuntimeError, "No RuntimeError to dump unexpected type") do
        json = Common.safe_dump_simple_hash_array(records);
      end

      assert_not_equal(0, $log.logs.length, "Exception should be logged")
      assert($log.logs[-1].include?("source sequence is illegal/malformed utf-8"), "Except error in log: '#{$log.logs}'")
      assert_equal(nil, json, "Expect nil: #{json}")
    end

    def test_get_current_timezone
      $log = MockLog.new
      File.delete(@tmp_localtime_file.path)
      FileUtils.cp('/usr/share/zoneinfo/Asia/Shanghai', @tmp_localtime_file.path)
      Common.tzLocalTimePath = @tmp_localtime_file.path
      timezone = Common.get_current_timezone
      assert_equal([], $log.logs, "There was an error parsing the timezone")
      # sanity check
      assert_equal('China Standard Time', timezone, "timezone is not expected")
    end
    
    def test_get_current_timezone_symlink
      $log = MockLog.new
      File.delete(@tmp_localtime_file.path)
      File.symlink('/usr/share/zoneinfo/right/America/Los_Angeles', @tmp_localtime_file.path)
      Common.tzLocalTimePath = @tmp_localtime_file.path
      timezone = Common.get_current_timezone
      assert_equal([], $log.logs, "There was an error parsing the timezone")
      # sanity check
      assert_equal('Pacific Standard Time', timezone, "timezone is not expected")
    end
    
    def test_get_current_timezone_relative_symlink
      $log = MockLog.new
      File.delete(@tmp_localtime_file.path)
      File.symlink('/etc/../usr/share/zoneinfo/right/America/Los_Angeles', @tmp_localtime_file.path)
      Common.tzLocalTimePath = @tmp_localtime_file.path
      timezone = Common.get_current_timezone
      assert_equal([], $log.logs, "There was an error parsing the timezone")
      # sanity check
      assert_equal('Pacific Standard Time', timezone, "timezone is not expected")
    end
  end
end # Module OMS
