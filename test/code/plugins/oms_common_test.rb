require 'tempfile'
require 'openssl'
require 'net/http'
require 'net/https'
require 'json'
require 'fileutils'
require_relative 'omstestlib'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/oms_common'

module OMS

  class CommonTest < Test::Unit::TestCase

    # Extend class to reset OSFullName class variable
    class OMS::Common
      class << self
        def OSFullName=(os_full_name)
          @@OSFullName = os_full_name
        end

        def CurrentTimeZone=(timezone)
          @@CurrentTimeZone = timezone
        end

        def tzLocalTimePath=(localtimepath)
          @@tzLocalTimePath = localtimepath
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

    def test_get_os_full_name()
      conf = 'OSName=CentOS Linux\n' \
      'OSVersion=7.0\n' \
      'OSFullName=CentOS Linux 7.0 (x86_64)\n'\
      'OSAlias=UniversalR\n'\
      'OSManufacturer=Central Logistics GmbH\n'
      File.write(@tmp_conf_file.path, conf)
      os_full_name = Common.get_os_full_name(@tmp_conf_file.path)
      assert_equal('CentOS Linux 7.0 (x86_64)', os_full_name, 'Did not extract the full os name correctly')

      os_full_name_2 = Common.get_os_full_name()
      assert_equal(os_full_name, os_full_name_2, "Getting the os full name a second time should return the cashed result")
    end

    def test_get_os_full_name_wrong_path()
      fake_conf_path = @tmp_conf_file.path + '.fake'
      assert_equal(false, File.file?(fake_conf_path))
      os_full_name = Common.get_os_full_name(fake_conf_path)
      assert_equal(nil, os_full_name, "Should not find data in a non existing file")
      
      # Should retry the second time since it did not find anything before
      File.write(@tmp_conf_file.path, 'OSFullName=Ubuntu 14.04 (x86_64)\n')    
      os_full_name = Common.get_os_full_name(@tmp_conf_file.path)
      assert_equal('Ubuntu 14.04 (x86_64)', os_full_name, 'Did not extract the full os name correctly')
    end

    def test_get_os_full_name_missing_field()
      conf = 'OSName=CentOS Linux\n' \
      'OSManufacturer=Central Logistics GmbH\n'
      File.write(@tmp_conf_file.path, conf)
      os_full_name = Common.get_os_full_name(@tmp_conf_file.path)
      assert_equal(nil, os_full_name, "Should not find data when field is missing")
    end

    def test_get_hostname
      $log = MockLog.new
      hostname = Common.get_hostname
      assert_equal([], $log.logs, "There was an error parsing the hostname")
      # Sanity check
      assert_not_equal(nil, hostname, "Could not get the hostname")
      assert(hostname.size > 0, "Hostname returned is empty")
    end

    def test_format_time
      formatted_time = Common.format_time(1446682353)
      assert_equal("2015-11-05T00:12:33.000Z", formatted_time, "The time is not in the correct iso8601 format with millisecond precision.")
      formatted_time = Common.format_time(1447984563.078218)
      assert_equal("2015-11-20T01:56:03.078Z", formatted_time, "The time is not in the correct iso8601 format with millisecond precision.")
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
      assert_equal(true, http.use_ssl?, "Http should use ssl")
    end

    def test_parse_json_record_encoding
      record = "syslog record"
      parsed_record = Common.parse_json_record_encoding(record);
      assert_equal(record.to_json, parsed_record, "parse json record no encoding failed");
      
      record = {}
      record["DataItems"] = [ {"Message" => "iPhone\xAE"} ];
      parsed_record = Common.parse_json_record_encoding(record);
      assert_equal("{\"DataItems\":[{\"Message\":\"iPhone®\"}]}", parsed_record, "parse json record utf-8 encoding failed");
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
  end
end # Module OMS
