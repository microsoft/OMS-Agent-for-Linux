#!/usr/local/bin/ruby
require 'open3'
require 'json'
require 'base64'

module WLM
  
  # Wlm specific heartbeat that is independent of discovery; meant to be monitored by WLI team
  # Refer in_wlm_input for the input plugin & wlm_heartbeat.conf for config

  class WlmHeartbeat

    require_relative 'oms_common'
  
    def initialize(common = nil)
      @common = common!=nil ? common : OMS::Common
    end

    def get_data(time, data_type, ip)
      data = {}
      # Capturing minimalistic data for the heartbeat
      data["Timestamp"] = time
      data["Collections"] = [{"CounterName"=>"WLIHeartbeat","Value"=>1}]
      data["Computer"] = @common.get_fully_qualified_domain_name

      return {
        "DataType" => data_type, 
        "IPName" => ip, 
        "DataItems"=> [data]
      }
    end #get_data

  end #class

end #module
