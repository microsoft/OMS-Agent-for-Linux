# Linux Squid Proxy Log Monitoring Solution for Operations Management Suite
# Developed by Alessandro Cardoso, v 1.0, Feb 2017
# Microsoft Enterprise Services Delivery
# Asia Pacific, Greater China, India & Japan 
# 
# Library for Squid to allow capture Squid utilisation statistics 
#
#
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

