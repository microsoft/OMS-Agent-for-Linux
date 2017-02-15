require 'fluent/test'
require_relative '../../../source/code/plugins/filter_scom_simple_match'
require 'socket'

  class SCOMSimpleMatchTest < Test::Unit::TestCase
    
    def setup
      Fluent::Test.setup
    end
    
    def teardown
    end
    
    CONFIG = %[
      regexp1 message TestRegex1
      event_id1 0001
      event_desc1 TestDesc1
      regexp2 message TestRegex2
      event_id2 0002
      event_desc2 TestDesc2
    ]
    
    def create_driver(conf=CONFIG)
      Fluent::Test::FilterTestDriver.new(Fluent::SCOMSimpleMatchFilter).configure(conf)
    end
    
    def test_configure
      d = create_driver
      regexps = d.instance.regexps
      assert_equal(regexps.length,1)
      assert_equal(regexps.has_key?('message'), true)
      assert_equal(regexps['message'].length, 2)
    end
    
    def test_event
      d = create_driver
      
      d.run do
        d.emit({"message"=>"TestRegex1"})
        d.emit({"message"=>"WrongRegex"})
        d.emit({"message"=>"TestRegex2"})
      end
      
      assert_equal(d.emits.length, 3)
      assert_equal(d.emits[0][2], {"HostName"=>"#{Socket.gethostname}", "CustomEvents"=>[{"CustomMessage"=>"TestDesc1", "EventID"=>"0001", "TimeGenerated"=>"#{d.emits[0][1]}"}]})
      assert_equal(d.emits[2][2], {"HostName"=>"#{Socket.gethostname}", "CustomEvents"=>[{"CustomMessage"=>"TestDesc2", "EventID"=>"0002", "TimeGenerated"=>"#{d.emits[2][1]}"}]})
      assert_equal(d.emits[1][2], {"message"=>"WrongRegex"})
    end
    
  end

