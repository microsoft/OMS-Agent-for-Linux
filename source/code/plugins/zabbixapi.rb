require_relative "zabbix_client"

class ZabbixApiWrapper
  attr :client

  def self.connect(options = {})
    new(options)
  end

  def self.current
    @current ||= ZabbixApiWrapper.new
  end

  def query(data)
    @client.api_request(:method => data[:method], :params => data[:params])
  end

  def initialize(options = {}, mock_client = nil)
	if mock_client.nil? == true
		@client = ZabbixApi::Client.new(options)
	else
		@client = mock_client
	end
	
    unless @client.api_version =~ /2\.\d+\.\d+/
      raise "Zabbix API version: #{@client.api_version} is not support by this version of zabbixapi"
    end
  end
end