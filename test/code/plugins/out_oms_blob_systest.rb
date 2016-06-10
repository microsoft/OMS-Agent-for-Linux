require 'fluent/test'
require_relative ENV['BASE_DIR'] + '/source/ext/fluentd/test/helper'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/out_oms_blob'
require_relative 'omstestlib'
require_relative 'out_oms_systestbase'

class OutOMSBlobTest < OutOMSSystemTestBase

  def test_send_data
    # Onboard to create cert and key
    prep_onboard
    do_onboard
    
    conf = load_configurations

    tag = 'test'
    d = Fluent::Test::OutputTestDriver.new(Fluent::OutputOMSBlob, tag).configure(conf)

    output = d.instance
    output.start

    # Mock custom log data
    time = Time.now.utc
    tag = "oms.blob.CustomLog.CUSTOM_LOG_BLOB.Test_CL_cec9ea66-f775-41cd-a0a6-2d0f0ffdac6f.tmp.oms.log.test.log"
    records = ["#{time}: Message 1", "#{time}: Message 2", "#{time}: Message 3"]
    assert_nothing_raised(RuntimeError, "Failed to send custom log data : '#{$log.logs}'") do
      output.handle_records(tag, records)
    end

    assert_equal(0, $log.logs.length, "No exception should be logged")

    # Mock custom log data
    $log.clear
    time = Time.now.utc
    tag = "oms.blob.CustomLog"
    records = ["#{time}: Message 1", "#{time}: Message 2", "#{time}: Message 3"]
    assert_nothing_raised(RuntimeError, "Failed to send custom log data : '#{$log.logs}'") do
      output.handle_records(tag, records)
    end

    assert($log.logs[-1].include?("The tag does not have at least 4 parts"), "Except error in log: '#{$log.logs}'")
  end

end
