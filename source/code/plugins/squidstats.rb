# Develpped by Alessandro Cardoso
# 
# Library for Squid to allow capture Squid utilisation statistics 
#
##sample data (full sample data at the end of this file)
require 'open3'
require 'syslog/logger'
require_relative 'omslog'

module Fluent

  class SquidLoggingBase
     def logerror(text)
     end
  end

  class RuntimeError < SquidLoggingBase
    def logerror(text)
      $log.error "RuntimeError: #{text}"
    end
  end



#### Utilisation Statistics

  class SquidUtilisation < Input
    Fluent::Plugin.register_input('SquidUtilisation', self)

    config_param :host, :string, :default => 'localhost'
    config_param :tag, :string, :default => nil
    config_param :port, :integer, :default => 3128
    config_param :interval, :time, :default => '30s'

    def initialize
      super
    end  
       
    def configure(conf)
      super
      if !@tag 
        raise ConfigError, "'tag' option is required on SquidUtilisation input"
      end
     
    end

    def start
      super
      @finished = false
      @squidstat_lib = Fluent::SquidUtilisationLib.new
      @thread = Thread.new(&method(:run_periodic))
    end

    def receive_data(line) 
       begin
        line.chomp!  
        utilization_transformed_record = @squidstat_lib.utilization_transform_and_wrap(line) 
        time = Time.now
        if time && utilization_transformed_record
          tag=@tag
          router.emit(tag, time, utilization_transformed_record)
        end
      rescue => e
        $log.warn line.dump, error: e.to_s
      end
    end

   def run_periodic
     @command = "squidclient -h localhost -p #{port.to_s} cache_object://localhost/ mgr:5min "
     until @finished
        begin
          sleep @interval
            Open3.popen3(@command) {|writeio, readio, errio, wait_thread|
            writeio.close

            while line = readio.gets
              #OMS::Log.warn_once("line- #{line} ")   #log for debug perspective
              receive_data(line)
            end

            while line = errio.gets
              $log.error "Squid:#{host} - #{line}"
                receive_data(line)
            end
            
            wait_thread.value #wait until child process terminates
          }
          rescue Errno::ENOENT
            OMS::Log.error_once("Service Squid Status is not available on this machine.")
          rescue
           OMS::Log.error_once("SquidUtilisation failed to run or shutdown child process #{$!.to_s}")
          end
      end #begin
    end #def

    def shutdown
      @finished = true 
      @thread.join
    end

  end # class

  class SquidUtilisationLib

    # utilisation 5min
    def utilization_transform_data(record)
      
           
      @temp = record.sub "=", ":"
      @values = @temp.split(":")
    
      if  @values && @values.length > 0
       
        rec= @values
        #rec = Hash[@values]
        transformed_rec = {}
        begin

       
          _key=rec.first
          _value=rec.last

          #recover all stats 
          #transformed_rec[_key] = _value 

           if (_key.include?("client") && _value.include?("ERROR")   )
               transformed_rec["SquidIsRunning"] = 0
               transformed_rec["SquidStatus"] = "Stopped"
               transformed_rec["Facility"] = "Deamon"
               transformed_rec["Severity"] = "err"
               OMS::Log.error_once("Service Squid Status is not available on this machine.")

           else
               transformed_rec["SquidIsRunning"] = 1 if (_key.include?("client"))
               transformed_rec["SquidStatus"] = "Running"
               transformed_rec["Facility"] = "Deamon"
               transformed_rec["Severity"] = "notice"
    
               #header
   	       transformed_rec["SquidServer"] = _value if (_key.end_with?("Server"))
    	       transformed_rec["SquidXCacheLookup"] = _value if (_key.end_with?("X-Cache-Lookup")) 
   	       transformed_rec["SquidXCache"] = _value if (_key.end_with?("X-Cache")) 
   	       transformed_rec["SquidCpuTime" ] = _value.to_f if (_key.end_with?("cpu_time")) 
   	       transformed_rec["SquidCpuUsage"] = _value.to_f if (_key.end_with?("cpu_usage")) 
     
  	       #client stats
  	       transformed_rec["ClientHttpRequests"] = _value.to_f if (_key.include?("client_http.requests")) 
 	       transformed_rec["ClientHttpHits"] = _value.to_f if (_key.include?("client_http.hits")) 
   	       transformed_rec["ClientHhttpErrors"] = _value.to_f if (_key.include?("client_http.errors")) 
 	    
 	       #server stats
  	       transformed_rec["ServerAllRequests"] = _value.to_f if (_key.end_with?("server.all.requests")) 
               transformed_rec["ServerAllErrors"] = _value.to_f if (_key.end_with?("server.all.errors")) 
               transformed_rec["ServerAllKbytesIn"] = _value.to_f if (_key.end_with?("server.all.kbytes_in")) 
               transformed_rec["ServerAllKbytesOut"] = _value.to_f if (_key.end_with?("server.all.kbytes_out")) 
          end
        rescue => e
           $log.warn e.to_s
        end
 
        dataitems = {}       
        dataitems["Timestamp"] = OMS::Common.format_time(Time.now.to_f)
        dataitems["Host"] = OMS::Common.get_hostname
        dataitems["ObjectName"] = "SquidUtilisation"
        dataitems["InstanceName"] = OMS::Common.get_hostname
        collections = []

        transformed_rec.each { |k,v|
          if v.nil? or v == "nil"
            OMS::Log.warn_once("Dropping null value for counter #{k}")
          else
            counter_pair = {"CounterName" => k, "Value" => v} 
            #OMS::Log.warn_once("Squid Utilisation- #{k} : #{_value.to_f}")   #log for debug perspective
            collections.push(counter_pair) 
          end
        }
        dataitems["Collections"] = collections       
                  
        return dataitems
      end   #if
    end #def

    def utilization_transform_and_wrap(record)
      return nil if record.to_s.empty?

      data_items = utilization_transform_data(record)
      if (!data_items.nil? and data_items.size>0)
        wrapper = {
          "DataType"=>"LINUX_PERF_BLOB",
          "IPName"=>"LogManagement",
          "DataItems"=>[data_items]
        }
        return wrapper
      else
        return nil 
      end  #if
    end # def


  end #class SquidUtilisation

#############################################################


#### Squid Stats

  class SquidStats < Input
    Fluent::Plugin.register_input('SquidStats', self)

    config_param :host, :string, :default => 'localhost'
    config_param :tag, :string, :default => nil
    config_param :port, :integer, :default => 3128
    config_param :interval, :time, :default => '30s'  
  
    def initialize
      super
      require_relative 'omslog'

    end  
       
    def configure(conf)
      super
      if !@tag 
        raise ConfigError, "'tag' option is required on SquidStats input"
      end
     end

    def start
      super
      @squidstats_lib = Fluent::SquidStatsLib.new
      @finished = false
      @thread = Thread.new(&method(:run_periodic))
    end

    def receive_data(line) 
       begin
        line.chomp!
        records_transformed_record = @squidstats_lib.records_transform_and_wrap(line) 
        time = Time.now
        if time && records_transformed_record
          tag=@tag
          router.emit(tag, time, records_transformed_record)
        end
      rescue => e
        $log.warn line.dump, error: e.to_s
      end
    end


   def run_periodic 
     @command = "squidclient -h localhost -p #{port.to_s} cache_object://localhost/ mgr:info "
     until @finished
        begin
          sleep @interval
 
          Open3.popen3(@command) {|writeio, readio, errio, wait_thread|
            writeio.close
            while line = readio.gets
              receive_data(line)
            end

            while line = errio.gets
              $log.error "#{line}"
              receive_data(line)
            end
            
            wait_thread.value #wait until child process terminates
          }
          rescue Errno::ENOENT
            OMS::Log.error_once("Service Squid Status is not available on this machine.")
          rescue
           OMS::Log.error_once("Squidstats failed to run or shutdown child process #{$!.to_s}")
          end
      end  #begin
    end  #def
   
    def shutdown
      @finished = true 
      @thread.join
    end

  end #class



  class SquidStatsLib 

    def SquidLogError(line)
           # Parse the first argument as the number of syslog events to generate
           log = Syslog::Logger.new 'SquidStatus'
           msg = "#{line}"
           # Ruby seems to have a bug : the error severity level appears as a warning in syslog 
           log.error msg
     end

    # squid stats
    def records_transform_data(record)

       @values = record.split(":", 2)
    
       if  @values && @values.length > 0
       
        rec= @values
        #rec = Hash[@values]
        transformed_rec = {}
        begin

          _key=rec.first
          _value=rec.last

          #recover all stats 
          #transformed_rec[_key] = _value 

           if (_key.include?("client") && _value.include?("ERROR")   )
              transformed_rec["SquidIsRunning"] = 0
              transformed_rec["SquidStatus"] = "Stopped"
              transformed_rec["Facility"] = "Deamon"
              transformed_rec["Severity"] = "err"
              OMS::Log.error_once("Service Squid Status is not available on this machine.")
              #SquidLogError("Error: Service Squid Status is not running on this machine")
           else
              transformed_rec["SquidIsRunning"] = 1 if (_key.include?("client"))
              transformed_rec["SquidStatus"] = "Running"
              transformed_rec["Facility"] = "Deamon"
              transformed_rec["Severity"] = "notice"
        
              #header
              transformed_rec["SquidServer"] = _value if (_key.end_with?("Server"))
              transformed_rec["SquidXCacheLookup"] = _value if (_key.end_with?("X-Cache-Lookup")) 
              transformed_rec["SquidXCache"] = _value if (_key.end_with?("X-Cache")) 

              #Resource usage for squid
              transformed_rec["SquidUpTime" ] = _value.to_f if (_key.end_with?("UP Time")) 
              transformed_rec["SquidCpuTime"] = _value.to_f if (_key.end_with?("CPU Time")) 
              transformed_rec["SquidCpuUsage"] = _value.to_f if (_key.end_with?("CPU Usage")) 
     
              #Memory usage for squid 
              transformed_rec["SquidMemoryTotalInUse"] = _value.to_f if (_key.end_with?("Total in use")) 
              transformed_rec["SquidMemoryTotalFree"] = _value.to_f if (_key.end_with?("Total free")) 

     
              #Connection information for squid
              transformed_rec["SquidNumClientsAccessingCache"] = _value.to_f if (_key.end_with?("Number of clients accessing cache")) 
              transformed_rec["SquidNumHTTPRequestsReceived"] = _value.to_f if (_key.end_with?("Number of HTTP requests received")) 
              transformed_rec["SquidRequestFailureRatio"] = _value.to_f if (_key.end_with?("Request failure ratio")) 
              transformed_rec["SquidAvgHTTPRequestsPerMin"] = _value.to_f if (_key.end_with?("Average HTTP requests per minute since start")) 
            end

        rescue => e
           $log.warn e.to_s
        end
   
        dataitems = {}       
        dataitems["Timestamp"] = OMS::Common.format_time(Time.now.to_f)
        dataitems["Host"] = OMS::Common.get_hostname
        dataitems["ObjectName"] = "SquidStats"
        dataitems["Status"] = transformed_rec["SquidStatus"].to_s
        dataitems["InstanceName"] = "Squid"   #OMS::Common.get_hostname
        collections = []

        transformed_rec.each { |k,v|
          if v.nil? or v == "nil"
            OMS::Log.info_once("Dropping null value for counter #{k}")
          else
            counter_pair = {"CounterName" => k, "Value" => v} 
            # OMS::Log.warn_once("Squidstats- #{k} : #{v}")   #for debug purpose 
            collections.push(counter_pair) 
          end
        }
        dataitems["Collections"] = collections       
                  
        return dataitems
       end #if 
      
    end #def

    def records_transform_and_wrap(record)
      return nil if record.to_s.empty?

      data_items = records_transform_data(record)
      if (!data_items.nil? and data_items.size>0)
        wrapper = {
          "DataType"=>"LINUX_PERF_BLOB",
          "IPName"=>"LogManagement",
          "DataItems"=>[data_items]
        }
        return wrapper
      else
        return nil 
      end  #if
    end # def


  end #class SquidStatslib
    
end  #module

#sample data
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
