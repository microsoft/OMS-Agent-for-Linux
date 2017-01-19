require 'fluent/test'
require_relative '../../../source/code/plugins/filter_scom_excl_correlation'
require 'socket'

  class SCOMExclCorTest < Test::Unit::TestCase
    
    def setup
      Fluent::Test.setup
    end
    
    def teardown
    end
    
    CONFIG = %[
      regexp1 message Stopping test process
      regexp2 message Starting test process
      event_id 0001
      event_desc TestDesc
      time_interval 5
    ]
    
    def create_driver(conf=CONFIG)
      Fluent::Test::FilterTestDriver.new(Fluent::SCOMExclusiveCorrelationFilter).configure(conf)
    end
    
    def test_configure
      d = create_driver
      assert_equal(d.instance.expression1, Regexp.compile('Stopping test process'))
      assert_equal(d.instance.expression2, Regexp.compile('Starting test process'))
      assert_equal(d.instance.key1, 'message')
      assert_equal(d.instance.key2, 'message')
      assert_equal(d.instance.time_interval, 5)
    end
    
  end

