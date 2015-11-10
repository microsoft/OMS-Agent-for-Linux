require 'tempfile'
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
      end
    end

    def setup
      @tmp_conf_file = Tempfile.new('oms_conf_file')
      # Reset the OS name between tests
      Common.OSFullName = nil
    end

    def teardown
      tmp_path = @tmp_conf_file.path
      assert_equal(true, File.file?(tmp_path))
      @tmp_conf_file.unlink
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
      assert_equal("2015-11-05T00:12:33Z", formatted_time, "The time should be in the iso8601 format.")
    end

    def test_create_error_tag
      assert_equal("ERROR::xyzzy::", Common.create_error_tag("xyzzy"))
      assert_equal("ERROR::123::", Common.create_error_tag(123))
      assert_equal("ERROR::::", Common.create_error_tag(nil))
    end

  end
end # Module OMS
