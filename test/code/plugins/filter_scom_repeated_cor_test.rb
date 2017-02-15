require 'fluent/test'
require_relative '../../../source/code/plugins/filter_scom_repeated_cor'
require 'socket'

  class SCOMCorMatchTest < Test::Unit::TestCase
    
    def setup
      Fluent::Test.setup
    end
    
    def teardown
    end
    
    CONFIG = %[
      regexp1 message Authentication Failed
      event_id 0001
      event_desc TestDesc
      time_interval 5
      num_occurences 3
    ]
    
    def create_driver(conf=CONFIG)
      Fluent::Test::FilterTestDriver.new(Fluent::SCOMRepeatedCorrelationFilter).configure(conf)
    end
    
    def test_configure
      d = create_driver
      assert_equal(d.instance.expression, Regexp.compile('Authentication Failed'))
      assert_equal(d.instance.key, 'message')
      assert_equal(d.instance.time_interval, 5)
      assert_equal(d.instance.num_occurences, 3)
    end
    
    def test_filter
      d = create_driver
      
      d.run do
        d.emit({"message"=>"Authentication Failed"})
        d.emit({"message"=>"Authentication Failed"})
        d.emit({"message"=>"Authentication Failed"})
      end
      
      assert_equal(d.emits.length, 3)
      assert_equal(d.emits[0][2], {"message"=>"Authentication Failed"})
      assert_equal(d.emits[1][2], {"message"=>"Authentication Failed"})
      assert_equal(d.emits[2][2], {"HostName"=>"#{Socket.gethostname}", "CustomEvents"=>[{"CustomMessage"=>"TestDesc", "EventID"=>"0001", "TimeGenerated"=>"#{d.emits[2][1]}"}]})
    end
    
  end
