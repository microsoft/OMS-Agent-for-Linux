## squid_log_parser_plugintest
## Created by Alessandro Cardoso
## 

require 'fluent/test'
require 'fluent/test/parser_test'
require_relative '../../../source/code/plugins/squidlogparser.rb'
require_relative 'omstestlib'
 
class SquidLogParserTest < Test::Unit::TestCase
   class << self
     def startup
        @@squidlog = Fluent::SquidLogParser.new()
     end #def

     def shutdown
        #no op
     end #def
   end #class

   def test_parse

     text = '1486686388.768      0 10.1.1.4 TCP_MISS/200 2965 GET cache_object://localhost/5min - HIER_NONE/- text/plain'  
     record = @@squidlog.parse(text)
     assert_equal record['HostName'], 'contoso.SquidServer1'
     assert_equal record['ResourceID'], 'Squid'
   
     text = '1486686229.592     97 10.1.1.4 TCP_MISS/301 483 open http://portal.azure.com/ - HIER_DIRECT/13.77.0.21 text/html'
     record = @@squidlog.parse(text)
     assert_equal record['HostName'], 'contoso.SquidServer1'
     assert_equal record['ResourceID'], 'Squid'

     text = '1486686488.885      0 10.1.1.4 TCP_DENIED/403 8175 POST http://www.testurl.com/ - HIER_NONE/- text/html'
     record = @@squidlog.parse(text)
     assert_equal record['HostName'], 'contoso.SquidServer1'
     assert_equal record['ResourceID'], 'Squid'

     text = '1486686167.769   5010 10.1.1.4 TCP_MISS/304 386 GET http://ctldl.windowsupdate.com/msdownload/update/v3/static/trustedr/en/disallowedcertstl.cab? - HIER_DIRECT/72.247.223.179 application/octet-stream'
     record = @@squidlog.parse(text)
     assert_equal record['HostName'], 'contoso.SquidServer1'
     assert_equal record['ResourceID'], 'Squid' 
  
     text = '1486686448.842     23 10.1.1.4 TCP_MISS/400 1513 open http://cloudtidings.com/ - HIER_DIRECT/192.0.78.25 text/html' 
     record = @@squidlog.parse(text)
     assert_equal record['HostName'], 'contoso.SquidServer1'
     assert_equal record['ResourceID'], 'Squid'
 
     text = '1486686629.120     23 10.1.1.4 TCP_MISS/400 1513 open http://cloudtidings.com/ - HIER_DIRECT/192.0.78.25 text/html'
     record = @@squidlog.parse(text)
     assert_equal record['HostName'], 'contoso.SquidServer1'
     assert_equal record['ResourceID'], 'Squid'

  end  #def

end  #class


#Squidstats - sample data
#HTTP/1.1 200 OK
#Server: squid/3.3.8
#Mime-Version: 1.0
#Date: Wed, 09 Nov 2016 17:17:59 GMT
#Content-Type: text/plain
#Expires: Wed, 09 Nov 2016 17:17:59 GMT
#Last-Modified: Wed, 09 Nov 2016 17:17:59 GMT
#X-Cache: MISS from Squid
#X-Cache-Lookup: MISS from Squid:3128
#Via: 1.1 Squid (squid/3.3.8)
#Connection: close
#
#sample_start_time = 1478711565.77478 (Wed, 09 Nov 2016 17:12:45 GMT)
#sample_end_time = 1478711865.78030 (Wed, 09 Nov 2016 17:17:45 GMT)
#client_http.requests = 0.000000/sec
#client_http.hits = 0.000000/sec
#client_http.errors = 0.000000/sec
#client_http.kbytes_in = 0.000000/sec
#client_http.kbytes_out = 0.000000/sec
#client_http.all_median_svc_time = 0.000000 seconds
#client_http.miss_median_svc_time = 0.000000 seconds
#client_http.nm_median_svc_time = 0.000000 seconds
#client_http.nh_median_svc_time = 0.000000 seconds
#client_http.hit_median_svc_time = 0.000000 seconds
#server.all.requests = 0.000000/sec
#server.all.errors = 0.000000/sec
#server.all.kbytes_in = 0.000000/sec
#server.all.kbytes_out = 0.000000/sec
#server.http.requests = 0.000000/sec
#server.http.errors = 0.000000/sec
#server.http.kbytes_in = 0.000000/sec
#server.http.kbytes_out = 0.000000/sec
#server.ftp.requests = 0.000000/sec
#server.ftp.errors = 0.000000/sec
#server.ftp.kbytes_in = 0.000000/sec
#server.ftp.kbytes_out = 0.000000/sec
#server.other.requests = 0.000000/sec
#server.other.errors = 0.000000/sec
#server.other.kbytes_in = 0.000000/sec
#server.other.kbytes_out = 0.000000/sec
#icp.pkts_sent = 0.000000/sec
#icp.pkts_recv = 0.000000/sec
#icp.queries_sent = 0.000000/sec
#icp.replies_sent = 0.000000/sec
#icp.queries_recv = 0.000000/sec
#icp.replies_recv = 0.000000/sec
#icp.replies_queued = 0.000000/sec
#icp.query_timeouts = 0.000000/sec
#icp.kbytes_sent = 0.000000/sec
#icp.kbytes_recv = 0.000000/sec
#icp.q_kbytes_sent = 0.000000/sec
#icp.r_kbytes_sent = 0.000000/sec
#icp.q_kbytes_recv = 0.000000/sec
#icp.r_kbytes_recv = 0.000000/sec
#icp.query_median_svc_time = 0.000000 seconds
#icp.reply_median_svc_time = 0.000000 seconds
#dns.median_svc_time = 0.000000 seconds
#unlink.requests = 0.000000/sec
#page_faults = 0.000000/sec
#select_loops = 44.623251/sec
#select_fds = 0.000000/sec
#average_select_fd_period = 0.000000/fd
#median_select_fds = -1.000000
#swap.outs = 0.000000/sec
#swap.ins = 0.000000/sec
#swap.files_cleaned = 0.000000/sec
#aborted_requests = 0.000000/sec
#syscalls.disk.opens = 0.000000/sec
#syscalls.disk.closes = 0.000000/sec
#syscalls.disk.reads = 0.000000/sec
#syscalls.disk.writes = 0.000000/sec
#syscalls.disk.seeks = 0.000000/sec
#syscalls.disk.unlinks = 0.000000/sec
#syscalls.sock.accepts = 0.000000/sec
#syscalls.sock.sockets = 0.000000/sec
#syscalls.sock.connects = 0.000000/sec
#syscalls.sock.binds = 0.000000/sec
#syscalls.sock.closes = 0.000000/sec
#syscalls.sock.reads = 0.000000/sec
#syscalls.sock.writes = 0.000000/sec
#syscalls.sock.recvfroms = 0.000000/sec
#syscalls.sock.sendtos = 0.000000/sec
#cpu_time = 0.030230 seconds
#wall_time = 300.000552 seconds
#cpu_usage = 0.010077%
