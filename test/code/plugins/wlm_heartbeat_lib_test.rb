require 'test/unit'
require_relative '../../../source/code/plugins/wlm_heartbeat_lib'

class WlmHeartbeatTest < Test::Unit::TestCase
  
  class MockCommon 
    def get_fully_qualified_domain_name
      return "MockFQDN"
    end
  end # MockCommon

  def test_wlm_omi_data
    time = "Apr 24 11:24:14 UTC 2019"
  	data_type = "WLM_PERF_DATA_BLOB"
  	ip = "InfrastructureInsights"
  	expected_result = {"DataType"=> data_type,
                       "IPName"=> ip,
                       "DataItems"=> [{"Collections" => [{"CounterName"=>"WLIHeartbeat","Value"=>1}],
					                "Timestamp" => time,
					                "Computer" => "MockFQDN"}]
					}
    hearbeat_data = WLM::WlmHeartbeat.new(MockCommon.new).get_data(time, data_type, ip)
    assert_not_nil(hearbeat_data, "WlmHeartbeat is nil")
    assert_equal(expected_result, hearbeat_data, "WlmHeartbeat data not in expected format")
  end # test_wlm_omi_data
  
end # WlmHeartbeatTest