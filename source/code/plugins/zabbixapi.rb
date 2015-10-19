require_relative "zabbix_version"
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

  def initialize(options = {})
    @client = ZabbixApi::Client.new(options)
    unless @client.api_version =~ /2\.2\.\d+/
      raise "Zabbix API version: #{@client.api_version} is not support by this version of zabbixapi"
    end
  end
end