require 'fluent/test'
require_relative ENV['BASE_DIR'] + '/source/ext/fluentd/test/helper'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/oms_configuration'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/out_oms'
require_relative 'omstestlib'

class OutOMSPluginTest < Test::Unit::TestCase
  class Fluent::OutputOMS

    attr_reader :mock_data

    def initialize
      super
      @mock_data = {}
    end

    def handle_record(tag, record)
        @mock_data[tag] = record
    end
  end

  class OMS::Configuration
    class << self
      def configurationLoaded=(configLoaded)
        @@ConfigurationLoaded = configLoaded
      end
    end
  end

  def setup
    Fluent::Test.setup
    $log = OMS::MockLog.new
  end

  def teardown
  end

  def test_batch_data
    # mock the configuration to be loaded
    OMS::Configuration.configurationLoaded = true

    plugin = Fluent::OutputOMS.new

    buffer = Fluent::MemoryBufferChunk.new('memory')

    chunk = ''
    chunk << ['oms.security.local0.warn', {'DataType'=>'SECURITY_CISCO_ASA_BLOB', 'IPName'=>'LogManagement', 'DataItems'=>[{"ident"=>"%ASA-1-106100", "Timestamp"=>"2016-08-15T20:11:22Z", "Host"=>"oms64-u14-az-1", "Facility"=>"local0", "Severity"=>"warn", "Message"=>"Hello"}]}].to_msgpack
    chunk << ['oms.security.local0.warn', {'DataType'=>'SECURITY_CEF_BLOB', 'IPName'=>'LogManagement', 'DataItems'=>[{"ident"=>"CEF", "Timestamp"=>"2016-08-15T20:21:34Z", "Host"=>"oms64-u14-az-1", "Facility"=>"local0", "Severity"=>"warn", "Message"=>"Hello2"}]}].to_msgpack
    chunk << ['oms.syslog.local0.warn', {"DataType"=>"LINUX_SYSLOGS_BLOB", "IPName"=>"logmanagement", "DataItems"=>[{"ident"=>"niroy", "Timestamp"=>"2015-10-26T05:11:22Z", "Host"=>"niroy64-cent7x-01", "HostIP"=>"fe80::215:5dff:fe81:4c2f%eth0", "Facility"=>"local0", "Severity"=>"warn", "Message"=>"Hello"}]}].to_msgpack
    chunk << ['oms.syslog.local1.err', {"DataType"=>"LINUX_SYSLOGS_BLOB", "IPName"=>"logmanagement", "DataItems"=>[{"ident"=>"niroy", "Timestamp"=>"2015-10-26T05:11:22Z", "Host"=>"niroy64-cent7x-01", "HostIP"=>"fe80::215:5dff:fe81:4c2f%eth0", "Facility"=>"local1", "Severity"=>"err", "Message"=>"Hello2"}]}].to_msgpack
    chunk << ['oms.syslog.local1.err', {"DataType"=>"LINUX_SYSLOGS_BLOB", "IPName"=>"Security", "DataItems"=>[{"ident"=>"niroy", "Timestamp"=>"2015-10-26T05:11:22Z", "Host"=>"niroy64-cent7x-01", "HostIP"=>"fe80::215:5dff:fe81:4c2f%eth0", "Facility"=>"local1", "Severity"=>"err", "Message"=>"Hello2"}]}].to_msgpack

    buffer << chunk

    assert_nothing_raised(RuntimeError, "Failed to send data : '#{$log.logs}'") do
      plugin.write(buffer)

      assert_equal(4, plugin.mock_data.length, "Data type should be 4")
      assert(plugin.mock_data.has_key?('SECURITY_CISCO_ASA_BLOB.LOGMANAGEMENT'), "SECURITY_CISCO_ASA_BLOB.LOGMANAGEMENT should be there")
      assert(plugin.mock_data.has_key?('SECURITY_CEF_BLOB.LOGMANAGEMENT'), "SECURITY_CEF_BLOB.LOGMANAGEMENT should be there")
      assert(plugin.mock_data.has_key?('LINUX_SYSLOGS_BLOB.LOGMANAGEMENT'), "LINUX_SYSLOGS_BLOB.LOGMANAGEMENT should be there")
      assert_equal(2, plugin.mock_data['LINUX_SYSLOGS_BLOB.LOGMANAGEMENT']['DataItems'].length, "Number of DataItems in LINUX_SYSLOGS_BLOB data type should be 2")
      assert(plugin.mock_data.has_key?('LINUX_SYSLOGS_BLOB.SECURITY'), "LINUX_SYSLOGS_BLOB.SECURITY should be there")
    end

  end
end
