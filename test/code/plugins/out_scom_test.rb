require 'fluent/test'
require_relative '../../../source/ext/fluentd/test/helper'
require_relative '../../../source/code/plugins/scom_configuration'
require_relative '../../../source/code/plugins/out_scom'
require_relative 'omstestlib'

class OutSCOMPluginTest < Test::Unit::TestCase
  class Fluent::OutputSCOM

    attr_reader :mock_data

    def initialize
      super
      @mock_data = {}
    end

    def handle_record(tag, record)
        unless @mock_data[tag]
          @mock_data[tag] = []
        end
        @mock_data[tag].push(record)
    end
  end

  class SCOM::Configuration
    class << self
      def config_loaded=(configLoaded)
        @@configuration_loaded = configLoaded
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
    SCOM::Configuration.config_loaded = true

    plugin = Fluent::OutputSCOM.new

    buffer = Fluent::MemoryBufferChunk.new('memory')

    chunk = ''
    chunk << ['scom.event', {"HostName": "scomtest","CustomEvents": [{"EventID":"6000","CustomMessage": "My Message","TimeGenerated": "1476098630"}]}].to_msgpack
    chunk << ['scom.perf', {"PerformanceDataList": [{"InstanceName": "MongoDB","ObjectName": "dnstest","TimeSampled": "1476274284","Counters": [{"CounterName": "Counter1","Value": "15"},{"CounterName": "Counter2","Value": "25"}]}]}].to_msgpack
    chunk << ['scom.perf', {"PerformanceDataList": [{"InstanceName": "MongoDB","ObjectName": "dnstest","TimeSampled": "1476274284","Counters": [{"CounterName": "Counter1","Value": "10"},{"CounterName": "Counter2","Value": "20"}]}]}].to_msgpack
    chunk << ['scom.event', {"HostName": "scomtest","CustomEvents": [{"EventID":"6001","CustomMessage": "My Message 1","TimeGenerated": "1476098631"}]}].to_msgpack
    chunk << ['scom.event', {"HostName": "scomtest","CustomEvents": [{"EventID":"6002","CustomMessage": "My Message 2","TimeGenerated": "1476098632"}]}].to_msgpack

    buffer << chunk

    assert_nothing_raised(RuntimeError, "Failed to send data : '#{$log.logs}'") do
      plugin.write(buffer)

      assert_equal(3, plugin.mock_data['scom.event'].length)
      assert_equal(2, plugin.mock_data['scom.perf'].length)
      assert(plugin.mock_data['scom.event'][0].has_key?('CustomEvents'), "CustomEvents should be there")
      assert(plugin.mock_data['scom.perf'][0].has_key?('PerformanceDataList'), "PerformanceDataList should be there")
    end

  end
end

