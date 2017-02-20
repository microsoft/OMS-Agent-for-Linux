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
        
    def self.get_scom_record(time, event_id, event_desc)
      scom_record = {
          "CustomMessage"=>event_desc,
          "EventID"=>event_id,
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
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
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
