module Fluent

  class OutputOMS < BufferedOutput

    Plugin.register_output('out_oms', self)

    # Endpoint URL ex. localhost.local/api/

    def initialize
      super
      require 'net/http'
      require 'net/https'
      require 'uri'
      require 'yajl'
      require 'openssl'
      require_relative 'omslog'
    end

    config_param :omsadmin_conf_path, :string, :default => '/etc/opt/microsoft/omsagent/conf/omsadmin.conf'
    config_param :cert_path, :string, :default => '/etc/opt/microsoft/omsagent/certs/oms.crt'
    config_param :key_path, :string, :default => '/etc/opt/microsoft/omsagent/certs/oms.key'

    def configure(conf)
      super
    end

    def start
      super
      @loaded_endpoint = false
      @loaded_certs = false
      @uri_endpoint = nil
    end

    def shutdown
      super
    end

    def test_onboard_file(file_name)
      if !File.file?(file_name)
        OMS::Log.error_once("Could not find #{file_name} Make sure to onboard.")
        return false
      end
      
      if !File.readable?(file_name)
        OMS::Log.error_once("Could not read #{file_name} Check that the read permissions are set for the omsagent user")
        return false
      end

      return true
    end


    def load_endpoint
      return true if @loaded_endpoint
      return false if !test_onboard_file(@omsadmin_conf_path)

      endpoint_lines = IO.readlines(@omsadmin_conf_path).select{ |line| line.start_with?("OMS_ENDPOINT")}
      if endpoint_lines.size == 0
        OMS::Log.error_once("Could not find OMS_ENDPOINT setting in #{@omsadmin_conf_path}")
        return false
      elsif endpoint_lines.size > 1
        OMS::Log.log_warning_once("Found more than one OMS_ENDPOINT setting in #{@omsadmin_conf_path}, will use the first one.")
      end

      begin
        endpoint_url = endpoint_lines[0].split("=")[1].strip
        @uri_endpoint = URI.parse( endpoint_url )
      rescue => e
        OMS::Log.error_once("Error parsing endpoint url. #{e}")
        return false
      else
        @loaded_endpoint = true
        return true
      end
    end

    def load_certs
      return true if @loaded_certs
      return false if !test_onboard_file(@cert_path) or !test_onboard_file(@key_path)
      
      begin
        raw = File.read @cert_path
        @cert = OpenSSL::X509::Certificate.new raw
        raw = File.read @key_path
        @key  = OpenSSL::PKey::RSA.new raw
      rescue => e
        OMS::Log.error_once("Error loading certs: #{e}")
        return false
      else
        @loaded_certs = true
        return true
      end
    end

    def default_http
      http = Net::HTTP.new( @uri_endpoint.host, @uri_endpoint.port )
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.cert = @cert
      http.key = @key
      http.open_timeout = 30
      return http
    end

    def create_request(record)
      req = Net::HTTP::Post.new(@uri_endpoint.path)
      # Serialize the record
      req.body = Yajl.dump(record)
      return req
    end

    def start_request(req)
      # Tries to send the passed in request
      # Raises a RuntimeException if the request fails.
      # This exception should only be caught by the fluentd engine so that it retries sending this 
      begin
        res = nil
        secure_http = default_http
        res = secure_http.start { |http|  http.request(req) }
      rescue => e # rescue all StandardErrors
        # Server didn't respond
        raise "Net::HTTP.#{req.method.capitalize} raises exception: #{e.class}, '#{e.message}'"
      else
        # Exit on sucess 
        if res and res.is_a?(Net::HTTPSuccess)
          return
        end
        
        if res
          res_summary = "(#{res.code} #{res.message} #{res.body})"
        else
          res_summary = "(res=nil)"
        end
        raise "Failed to #{req.method} at #{@uri_endpoint} #{res_summary}"
      end # end begin
    end # end start_request

    def handle_record(tag, record)
      req = create_request(record)
      start = Time.now
      
      start_request(req)
      
      ends = Time.now
      time = ends - start
      count = record.has_key?('DataItems') ? record['DataItems'].size : 1
      @log.info "Success sending #{tag} x #{count} in #{time.round(2)}s"
    end

    # This method is called when an event reaches to Fluentd.
    # Convert the event to a raw string.
    def format(tag, time, record)
      @log.trace "Buffering #{tag}"
      [tag, record].to_msgpack
    end

    # This method is called every flush interval. Send the buffer chunk to OMS. 
    # 'chunk' is a buffer chunk that includes multiple formatted
    # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
    def write(chunk)
      # Quick exit if we are missing something
      if !load_endpoint or !load_certs
        raise 'Missing configuration. Make sure to onboard. Will continue to buffer data.'
      end

      # Group records based on their datatype because OMS does not support a single request with multiple datatypes. 
      datatypes = {}
      unmergable_records = []
      chunk.msgpack_each {|(tag, record)|
        if datatypes.has_key?(tag)
          # Merge instances of the same datatype together
          datatypes[tag]['DataItems'].concat(record['DataItems'])
        else
          if record.has_key?('DataItems')
            datatypes[tag] = record
          else
            unmergable_records << [tag, record]
          end
        end
      }

      @log.debug "Handling records by types"
      datatypes.each do |tag, record|
        handle_record(tag, record)
      end

      @log.debug "Handling #{unmergable_records.size} unmergeable records"
      unmergable_records.each { |tag, record|
        handle_record(tag, record)
      }
    end
   
  end # class OutputOMS

end # module Fluent
