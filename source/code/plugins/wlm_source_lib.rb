#!/usr/local/bin/ruby
require 'json'

module WLM
  class WlmSourceLib 

    attr_reader :method
    attr_reader :config

    def initialize(method, config_file_path, wli_source_lib = nil) 
      #read the method and the config json
      @method = method

      config_file = File.read(config_file_path)
      @config = JSON.parse(config_file)

      @wli_source_lib = get_source_lib unless wli_source_lib

    end #initialize

    def get_data(time, data_type, ip)
      @wli_source_lib.get_data(time, data_type, ip)
    end

    private
      def get_source_lib
        wlm_source = nil
        case @method 
        when "AutoDiscover::ProcessEnumeration"
          require_relative 'wlm_ad_pe_lib'
          source_lib = WLM::WlmProcessEnumeration.new(@config)
        when "WlmHeartbeat"
          require_relative 'wlm_heartbeat_lib'
          source_lib = WLM::WlmHeartbeat.new()
        else 
          raise "Not a valid method #{@method}" 
        end 
        return source_lib
      end #get_discovery_strategy

  end #class
end #module
