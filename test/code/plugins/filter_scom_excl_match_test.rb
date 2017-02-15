require 'fluent/test'
require_relative '../../../source/code/plugins/filter_scom_excl_match'
require 'socket'

  class SCOMExclMatchTest < Test::Unit::TestCase
    
    def setup
      Fluent::Test.setup
    end
    
    def teardown
    end
    
    CONFIG = %[
      regexp1 message Insertion of [a-z0-9]*
      regexp2 status succeeded
      event_id 0001
      event_desc TestDesc
    ]
    
    def create_driver(conf=CONFIG)
      Fluent::Test::FilterTestDriver.new(Fluent::SCOMExclusiveMatchFilter).configure(conf)
    end
    
    def test_configure
      d = create_driver
      assert_equal(d.instance.expression1, Regexp.compile('Insertion of [a-z0-9]*'))
      assert_equal(d.instance.expression2, Regexp.compile('succeeded'))
      assert_equal(d.instance.key1, 'message')
      assert_equal(d.instance.key2, 'status')
    end
    
    def test_filter
      d = create_driver
      
      d.run do
        d.emit({"message"=>"Insertion of doc1", "status"=>"succeeded"})
        d.emit({"message"=>"Insertion of doc2", "status"=>"failed"})
      end
      
      assert_equal(d.emits.length, 2)
      assert_equal(d.emits[1][2], {"HostName"=>"#{Socket.gethostname}", "CustomEvents"=>[{"CustomMessage"=>"TestDesc", "EventID"=>"0001", "TimeGenerated"=>"#{d.emits[1][1]}"}]})
      assert_equal(d.emits[0][2], {"message"=>"Insertion of doc1", "status"=>"succeeded"})
    end
    
  end
