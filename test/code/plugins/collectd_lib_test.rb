require 'test/unit'
require_relative '../../../source/code/plugins/collectd_lib'

class CollectdTest < Test::Unit::TestCase 

  class << self
    def startup
      @@collectd_lib = CollectdModule::Collectd.new
    end

    def shutdown
    end
  end

  def test_filter_null_or_empty_record_returns_empty
    assert_equal({}, @@collectd_lib.transform_and_wrap("", "testhost"), "empty record fails")
    assert_equal({}, @@collectd_lib.transform_and_wrap(nil, "testhost"), "null record fails")
  end

  def test_validate_record
    #case when type_instance=""
    input_record = {
                "values"=>[4447,4447],
                "dstypes"=>["derive","derive"],
                "dsnames"=>["rx","tx"],
                "interval"=>10.0,
                "host"=>"testhost",
                "plugin"=>"interface",
                "plugin_instance"=>"lo",
                "type"=>"if_packets",
                "type_instance"=>""
   	 }	
    expected_record = {"DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement", "DataItems"=>[{"Host"=>"testhost", "ObjectName"=>"if_packets", "InstanceName"=>"lo", "Collections"=>[{"CounterName"=>"rx", "Value"=>4447}, {"CounterName"=>"tx", "Value"=>4447}]}]}
    validate_record_helper(expected_record, input_record, "Record filter failed!")

    #Case when plugin_instance="" and type_instance not empty
    input_record = {
		"values"=>[0], 
		"dstypes"=>["gauge"], 
		"dsnames"=>["value"], 
		"interval"=>10.0, 
		"host"=>"testhost", 
		"plugin"=>"processes", 
		"plugin_instance"=>"", 
		"type"=>"ps_state", 
		"type_instance"=>"running"
    	}
   expected_record = {"DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement", "DataItems"=>[{"Host"=>"testhost", "ObjectName"=>"ps_state", "InstanceName"=>"_Total", "Collections"=>[{"CounterName"=>"running.value", "Value"=>0}]}]}
   validate_record_helper(expected_record, input_record, "Record filter failed!")
  
  end

  def validate_record_helper(expected, input, error_msg)
    returned_record = @@collectd_lib.transform_and_wrap(input, "testhost")
    #strip Timestamp key from dataitems for returned_record
    returned_record["DataItems"].each do |rec|
    	rec.tap{|x| x.delete("Timestamp")}
    end
    assert_equal(expected, returned_record, error_msg)
  end

end
