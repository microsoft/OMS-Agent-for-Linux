module Fluent

  class OutputOMS < Output

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

      @omslog = OMS_Log.new
      @error_proc = Proc.new {|message| $log.error message }
      @warn_proc  = Proc.new {|message| $log.warn message }
      @debug_proc = Proc.new {|message| $log.debug message }
    end

    def shutdown
      super
    end

    def test_onboard_file(file_name)
      if !File.file?(file_name)
        @omslog.log_once(@error_proc, @debug_proc, "Could not find #{file_name} Make sure to onboard.")
        return false
      end
      
      if !File.readable?(file_name)
        @omslog.log_once(@error_proc, @debug_proc, "Could not read #{file_name} Check that the read permissions are set for the omsagent user")
        return false
      end

      return true
    end


    def load_endpoint
      return true if @loaded_endpoint
      return false if !test_onboard_file(@omsadmin_conf_path)

      endpoint_lines = IO.readlines(@omsadmin_conf_path).select{ |line| line.start_with?("OMS_ENDPOINT")}
      if endpoint_lines.size == 0
        @omslog.log_once(@error_proc, @debug_proc, "Could not find OMS_ENDPOINT setting in #{@omsadmin_conf_path}")
        return false
      elsif endpoint_lines.size > 1
        @omslog.log_once(@warn_proc, @debug_proc, "Found more than one OMS_ENDPOINT setting in #{@omsadmin_conf_path}, will use the first one.")
      end

      begin
        endpoint_url = endpoint_lines[0].split("=")[1].strip
        @uri_endpoint = URI.parse( endpoint_url )
      rescue => e
        @omslog.log_once(@error_proc, @debug_proc, "Error parsing endpoint url. #{e}")
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
        @omslog.log_once(@error_proc, @debug_proc, "Error loading certs: #{e}")
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

    def start_request(req, tag)
      res = nil

      begin
        secure_http = default_http
        res = secure_http.start { |http|  http.request(req) }

      rescue => e # rescue all StandardErrors
        # Server didn't respond
        @omslog.log_once(@warn_proc, @debug_proc, "Net::HTTP.#{req.method.capitalize} raises exception: #{e.class}, '#{e.message}'")
        return false
      else
        if res and res.is_a?(Net::HTTPSuccess)
          return true
        end
        if res
          res_summary = "(#{res.code} #{res.message} #{res.body})"
        else
          res_summary = "(res=nil)"
        end
        @omslog.log_once(@warn_proc, @debug_proc, "Failed to #{req.method} #{tag} at #{@uri_endpoint} #{res_summary}")
        return false
      end # end begin
    end # end start_request

    def handle_record(tag, record)
      req = create_request(record)
      success = start_request(req, tag)
      if success
        $log.debug "Success sending #{tag}"
      end
      return success
    end

    def emit(tag, es, chain)
      # Quick exit if we are missing something
      if !load_endpoint or !load_certs
        return
      end

      es.each do |time, record|
        # Ignore empty records
        if record != nil and record.size > 0
          handle_record(tag, record)
        end
      end
      chain.next
    end
  end

end
