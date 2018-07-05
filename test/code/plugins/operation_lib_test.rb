# Copyright (c) Microsoft Corporation. All rights reserved.
require 'test/unit'
require_relative '../../../source/code/plugins/operation_lib'

class OperationTestRuntimeError < OperationModule::LoggingBase
  def log_error(text)
    raise text
  end
end

class OperationLib_Test < Test::Unit::TestCase
  class << self
    def startup
      @@operation_lib = OperationModule::Operation.new(OperationTestRuntimeError.new)
    end

    def shutdown
      #no op
    end
  end

  def test_filter_null_empty
    assert_equal({}, call_filter(nil), "null record fails")
    assert_equal({}, call_filter(""), "empty string record fails")
    assert_equal({}, call_filter(10), "int record fails")
    assert_equal({}, call_filter({}), "empty hash record fails")
  end

  def test_filter_invalid_hash
    assert_equal({}, call_filter({"name"=>"value"}), "invalid operation record - no type - fails")
    assert_equal({}, call_filter({"type"=>"oms"}), "invalid operation record - invalid type - fails")
    assert_equal({}, call_filter({"type"=>"out_oms"}), "invalid operation record - no config - fails")
    assert_equal({}, call_filter({"type"=>"out_oms", "config"=>"10"}), "invalid operation record - config not hash - fails")
    assert_equal({}, call_filter({"type"=>"out_oms", "config"=>{}}), "invalid operation record - config empty hash - fails")
    assert_equal({}, call_filter({"type"=>"out_oms", "config"=>{"buffer_queue_limit"=>10}}), "invalid operation record - config bufqlim not str - fails")
    assert_equal({}, call_filter({"type"=>"out_oms", "config"=>{"buffer_queue_limit"=>"10"}}), "invalid operation record - no bufqlen - fails")
    assert_equal({}, call_filter({"type"=>"out_oms", "config"=>{"buffer_queue_limit"=>"10"}, "buffer_queue_length"=>"10"}), "invalid operation record - bufqlen string - fails")
    assert_equal({}, call_filter({"type"=>"out_oms", "config"=>{"buffer_queue_limit"=>"str"}, "buffer_queue_length"=>10}), "invalid operation record - bufqlim not really int - fails")
  end

  def test_filter_valid_hash
    assert_equal({}, call_filter({"type"=>"out_oms", "config"=>{"buffer_queue_limit"=>"10"}, "buffer_queue_length"=>8}), "valid record - bufq below limit - fails")
    data_item = call_filter({"type"=>"out_oms", "config"=>{"buffer_queue_limit"=>"10"}, "buffer_queue_length"=>9})
    assert(data_item.has_key?("Timestamp") && data_item.has_key?("OperationStatus") && data_item.has_key?("Computer") && data_item.has_key?("Detail") && data_item.has_key?("Category") && data_item.has_key?("Solution") && data_item.has_key?("HelpLink"))
  end

  def test_generic_filter
    assert_equal({}, call_generic_filter(nil), "null record fails")
    assert_equal({}, call_generic_filter(""), "empty string record fails")
    assert_equal({}, call_generic_filter(10), "int record fails")
    assert_equal({}, call_generic_filter({}), "empty hash record fails")

    data_item = call_generic_filter({"message"=>"This is a test message"})
    assert(data_item.has_key?("Computer") && data_item.has_key?("Timestamp") && data_item.has_key?("Detail") && data_item.has_key?("OperationStatus") && data_item.has_key?("Category") && data_item.has_key?("Solution"))
    assert_equal("This is a test message", data_item["Detail"])
  end
  # wrapper to call filter
  def call_filter(record)
    @@operation_lib.filter(record, Time.now)
  end

  # wrapper to call generic filter
  def call_generic_filter(record)
    @@operation_lib.filter_generic(record, Time.now)
  end

end

