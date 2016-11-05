require 'fluent/test'
require 'fluent/test/parser_test'
require_relative '../../../source/code/plugins/squidlogparser.rb '
require_relative 'omstestlib'

class SquidLogParserTest < Test::Unit::TestCase

  CONFIG = %[
    format SquidLogParser
  ]


  def create_driver
    Fluent::Test::ParserTestDriver.new(Fluent::SquidLogParser.new).configure(CONFIG)
  end


  def test_parse

    d = create_driver()

    text = '1486686388.768      0 10.1.1.4 TCP_MISS/200 2965 GET cache_object://localhost/5min - HIER_NONE/- text/plain'
    d.instance.parse(text) do |_time, record|
      assert_equal record['HostName'], 'contoso.SquidServer1'
      assert_equal record['ResourceID'], 'Squid'
    end

    text = '1486686229.592     97 10.1.1.4 TCP_MISS/301 483 open http://portal.azure.com/ - HIER_DIRECT/13.77.0.21 text/html'
    d.instance.parse(text) do |_time, record|
      assert_equal record['HostName'], 'contoso.SquidServer1'
      assert_equal record['ResourceID'], 'Squid'
    end

   text = '1486686488.885      0 10.1.1.4 TCP_DENIED/403 8175 POST http://www.testurl.com/ - HIER_NONE/- text/html'
   d.instance.parse(text) do |_time, record|
      assert_equal record['HostName'], 'contoso.SquidServer2'
      assert_equal record['ResourceID'], 'Squid'
   end

    text = '1486686167.769   5010 10.1.1.4 TCP_MISS/304 386 GET http://ctldl.windowsupdate.com/msdownload/update/v3/static/trustedr/en/disallowedcertstl.cab? - HIER_DIRECT/72.247.223.179 application/octet-stream'
    d.instance.parse(text) do |_time, record|
      assert_equal record['HostName'], 'contoso.SquidServer1'
      assert_equal record['ResourceID'], 'Squid'
    end
    
    text = '1486686448.842     23 10.1.1.4 TCP_MISS/400 1513 open http://cloudtidings.com/ - HIER_DIRECT/192.0.78.25 text/html'
    d.instance.parse(text) do |_time, record|
      assert_equal record['HostName'], 'contoso.SquidServer2'
      assert_equal record['ResourceID'], 'Squid'
    end

    text = '1486686629.120     23 10.1.1.4 TCP_MISS/400 1513 open http://cloudtidings.com/ - HIER_DIRECT/192.0.78.25 text/html'
    d.instance.parse(text) do |_time, record|
      assert_equal record['HostName'], 'contoso.SquidServer1'
      assert_equal record['ResourceID'], 'Squid'
    end

  end

end
