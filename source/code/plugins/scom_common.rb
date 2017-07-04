module SCOM

  class RetryRequestException < Exception
    # Throw this exception to tell the fluentd engine to retry and
    # inform the output plugin that it is indeed retryable
  end

  class EventHolder
    def initialize(regexp, event_id, event_desc)
      @regexp = regexp
      @event_id = event_id
      @event_desc = event_desc
    end
            
    attr_reader :regexp
    attr_reader :event_id
    attr_reader :event_desc
  end

  class Common
    require_relative 'scom_configuration'
    require_relative 'omslog'
        
    def self.get_scom_record(time, event_id, event_desc, event_data)
      scom_record = {
          "CustomMessage"=>event_desc,
          "EventID"=>event_id,
          "EventData"=>event_data.to_s,
          "TimeGenerated"=>time.to_s,
      }
      scom_event = {
          "CustomEvents"=>[scom_record]
      }
      scom_event
    end
        
    def self.create_request(path, record, extra_headers=nil, serializer=method(:parse_json_record_encoding))
      req = Net::HTTP::Post.new(path)
      json_msg = serializer.call(add_scom_data(record))
      if json_msg.nil?
        return nil
      end
      req.body = json_msg
      req['Content-Type'] = 'application/json'
      return req
    end

    def self.add_scom_data(record)
      record["MonitoringId"]=SCOM::Configuration.monitoring_id
      record["HostName"]=SCOM::Configuration.fqdn
      event = {
          "events"=>record
      }
      event
    end
      
    def self.parse_json_record_encoding(record)
      msg = nil
      begin
        msg = JSON.dump(record)
      rescue => error 
        OMS::Log.warn_once("Skipping due to failed encoding for #{record}: #{error}")
      end
      return msg
    end
      
    def self.create_secure_http(uri)
      http = Net::HTTP.new( uri.host, uri.port )
      http.use_ssl = true
      if SCOM::Configuration.enable_server_auth
        OMS::Log.info_once("Enabling server certificate validation")
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      else
        OMS::Log.info_once("Disabling server certificate validation")
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end # if
      http.open_timeout = 30
      return http
    end

    def self.create_http(uri)
      http = create_secure_http(uri)
      http.cert = SCOM::Configuration.cert
      http.key = SCOM::Configuration.key
      return http
    end
      
    def self.start_request(req, secure_http, ignore404 = false)
      # Tries to send the passed in request
      # Raises an exception if the request fails.
      # This exception should only be caught by the fluentd engine so that it retries sending this 
      begin
        res = nil
        res = secure_http.start { |http|  http.request(req) }
      rescue => e # rescue all StandardErrors
        # Server didn't respond
        raise RetryRequestException, "Net::HTTP.#{req.method.capitalize} raises exception: #{e.class}, '#{e.message}'"
      else
        if res.nil?
          raise RetryRequestException, "Failed to #{req.method} at #{req.to_s} (res=nil)"
        end # if

        if res.is_a?(Net::HTTPSuccess)
          return res.body
        end # if

        if ignore404 and res.code == "404"
          return ''
        end # if

        if res.code != "200"
          # Retry all failure error codes...
          res_summary = "class=#{res.class.name}; code=#{res.code}; message=#{res.message}; body=#{res.body};)"
          raise RetryRequestException, "HTTP error: #{res_summary}"
        end # if

      end # end begin
    end # method start_request
      
  end # class Common
end # module SCOM

module Fluent

  class SCOMTimerFilterPlugin < Filter
  
    desc 'time interval before which regexp2 needs to match'
    config_param :time_interval, :integer, :default => 0
    desc 'event number to be sent to SCOM'
    config_param :event_id, :string, :default => nil
    desc 'event description to be sent to SCOM'
    config_param :event_desc, :string, :default => nil
  
    def initialize()
      super
      @exp1_found = false
      @timer = nil
      @lock = Mutex.new
    end
    
    def start
      super
    end
    
    def shutdown
      super
    end
    
    def configure(conf)
      super
      raise ConfigError, "Configuration does not have corresponding event ID" unless @event_id
      raise ConfigError, "Configuration does not have a time interval" unless (@time_interval > 0)
    end
    
    def flip_state()
      @lock.synchronize {
        @exp1_found = !@exp1_found
      }
    end
    
    def set_timer
      flip_state()
      @timer = Thread.new { sleep @time_interval; timer_expired() }
    end
    
    def reset_timer
      flip_state()
      @timer.terminate()
      @timer = nil
    end
    
    def timer_expired()
      $log.debug "Timer expired for event ID #{@event_id}"
      flip_state()
    end
    
  end # class SCOMTimerFilterPlugin
end # module Fluent
