require 'fluent/test'
require_relative '../../../source/code/plugins/filter_scom_converter'

  class SCOMConverterTest < Test::Unit::TestCase
    
    def setup
      Fluent::Test.setup
    end
    
    def teardown
    end
    
    CONFIG = %[
      event_id 0001
      event_desc TestDesc
    ]
    
    def create_driver(conf=CONFIG)
      Fluent::Test::FilterTestDriver.new(Fluent::SCOMConverter).configure(conf)
    end
    
    def test_configure
      d = create_driver
      assert_equal(d.instance.instance_variable_get(:@event_id), '0001')
      assert_equal(d.instance.instance_variable_get(:@event_desc), 'TestDesc')
    end
    
    def test_filter
      d = create_driver
      
      d.run do
        d.emit({"key1"=>"value1", "key2"=>"value2"})
        d.emit({"key1"=>"value1", "key2"=>[{"key11"=>"value11"}, {"key12"=>"value12"}]})
      end
      
      assert_equal(d.emits.length, 2)
      assert_equal(d.emits[0][2], {"CustomEvents"=>[{"CustomMessage"=>"TestDesc", "EventID"=>"0001", "EventData"=>"{\"key1\"=>\"value1\", \"key2\"=>\"value2\"}", "TimeGenerated"=>"#{d.emits[0][1]}"}]})
      assert_equal(d.emits[1][2], {"CustomEvents"=>[{"CustomMessage"=>"TestDesc", "EventID"=>"0001", "EventData"=>"{\"key1\"=>\"value1\", \"key2\"=>[{\"key11\"=>\"value11\"}, {\"key12\"=>\"value12\"}]}", "TimeGenerated"=>"#{d.emits[1][1]}"}]})
    end
    
  end
