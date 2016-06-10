require 'fluent/test'
require_relative ENV['BASE_DIR'] + '/source/ext/fluentd/test/helper'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/out_oms_api'
require_relative 'omstestlib'
require_relative 'out_oms_systestbase'

class OutOMSApiTest < OutOMSSystemTestBase 

  def test_send_data
    # Onboard to create cert and key
    prep_onboard
    do_onboard

    conf = load_configurations

    tag = 'test'
    d = Fluent::Test::OutputTestDriver.new(Fluent::OutputOMSApi, tag).configure(conf)

    output = d.instance
    output.start

    # Mock data
    tag = "oms.api.LinuxRestApiTest.ts"
    records = [
    {
      'id'=> 1,
      'ts'=> "#{Time.now.utc}", 
      'msg'=> 'Message 1' 
    },
    {
      'id'=> 2,
      'ts'=> "#{Time.now.utc}",
      'msg'=> 'Message 2'
    }]

    assert_nothing_raised(RuntimeError, "Failed to send data to api : '#{$log.logs}'") do
      output.handle_records(tag, records)
    end

    assert($log.logs.empty?, "No exception should be logged, but '#{$log.logs}'")

    $log.clear
    tag = "oms.api"
    assert_nothing_raised(RuntimeError, "Failed to send data to api : '#{$log.logs}'") do
      output.handle_records(tag, records)
    end

    assert(!$log.logs.empty?, "Expect error in log, but nothing")
    assert($log.logs[-1].include?("The tag does not have at least 3 parts"), "Expect error in log, but: '#{$log.logs}'")

    $log.clear
    tag = "oms.api.1abc"
    assert_nothing_raised(RuntimeError, "Failed to send data to api : '#{$log.logs}'") do
      output.handle_records(tag, records)
    end

    assert_not_equal(0, $log.logs.length, "Expect error in log, but nothing")
    assert($log.logs[-1].include?("The log type '1abc' is not valid"), "Expect error in log, but: '#{$log.logs}'")
  end

end
