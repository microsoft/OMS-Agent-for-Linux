require 'fluent/test'
require_relative '../../../source/code/plugins/filter_scom_cor_match'
require 'socket'

  class SCOMCorMatchTest < Test::Unit::TestCase
    
    def setup
      Fluent::Test.setup
    end
    
    def teardown
    end
    
    CONFIG = %[
      regexp1 message Installing package [A-Za-z0-9]*
      regexp2 message Install failed for package [A-Za-z0-9]*
      event_id 0001
      event_desc TestDesc
      time_interval 5
    ]
    
    def create_driver(conf=CONFIG)
      Fluent::Test::FilterTestDriver.new(Fluent::SCOMCorrelatedMatchFilter).configure(conf)
    end
    
    def test_configure
      d = create_driver
      assert_equal(d.instance.expression1, Regexp.compile('Installing package [A-Za-z0-9]*'))
      assert_equal(d.instance.expression2, Regexp.compile('Install failed for package [A-Za-z0-9]*'))
      assert_equal(d.instance.key1, 'message')
      assert_equal(d.instance.key2, 'message')
      assert_equal(d.instance.time_interval, 5)
    end
    
    def test_filter
      d = create_driver
      
      d.run do
        d.emit({"message"=>"Installing package Unittest1"})
        d.emit({"message"=>"Install failed for package Unittest1"})
      end
      
      assert_equal(d.emits.length, 2)
      assert_equal(d.emits[0][2], {"message"=>"Installing package Unittest1"})
      assert_equal(d.emits[1][2], {"HostName"=>"#{Socket.gethostname}", "CustomEvents"=>[{"CustomMessage"=>"TestDesc", "EventID"=>"0001", "TimeGenerated"=>"#{d.emits[1][1]}"}]})
    end
    
  end
