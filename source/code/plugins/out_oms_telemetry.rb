module Fluent

  class OutputOMSApi < BufferedOutput

    Plugin.register_output('out_oms_telemetry', self)

    def initialize
      super

      require 'base64'
      require 'digest'
      require 'json'
      require 'net/http'
      require 'net/https'
      require 'openssl'
      require 'socket'
      require 'time'
      require 'uri'
      require 'zlib'
      require 'securerandom'
      require_relative 'omslog'
      require_relative 'oms_configuration'
      require_relative 'oms_common'

      require 'fileutils'
      require 'gyoku'

      require_relative 'oms_common'
      require_relative 'agent_topology_request_script'
      require_relative 'oms_configuration'

    end

    config_param :omsadmin_conf_path, :string, :default => '/etc/opt/microsoft/omsagent/conf/omsadmin.conf'
    config_param :cert_path, :string, :default => '/etc/opt/microsoft/omsagent/certs/oms.crt'
    config_param :key_path, :string, :default => '/etc/opt/microsoft/omsagent/certs/oms.key'
    config_param :proxy_conf_path, :string, :default => '/etc/opt/microsoft/omsagent/proxy.conf'
    config_param :api_version, :string, :default => '2016-04-01'
    config_param :compress, :bool, :default => true
    config_param :time_generated_field, :string, :default => ''
    config_param :os_info, :string, :default => '/etc/opt/microsoft/scx/conf/scx-release' #optional
    config_param :pid_path, :string

    def configure(conf)
      super
    end

    def start
      super
      @proxy_config = OMS::Configuration.get_proxy_config(@proxy_conf_path)
      @logtype_regex = Regexp.new('^[A-Za-z][A-Za-z0-9_]{1,100}$')
    end

    def shutdown
      super
    end

    ####################################################################################################
    # Methods
    ####################################################################################################

    # post data to the service
    # parameters:
    #   log_type: string. log type
    #   time_generated_field_name: string. name of the time generated field
    #   records: hash[]. an array of data
    def post_data(log_type, time_generated_field_name, records, request_id)
      headers = {}
      req_date = Time.now.utc.strftime("%Y-%m-%dT%T.%N%:z")
      headers[OMS::CaseSensitiveString.new("x-ms-Date")] = req_date
      headers["User-Agent"] = get_user_agent
      headers[OMS::CaseSensitiveString.new("Accept-Language")] = "en-US"


      headers[OMS::CaseSensitiveString.new("X-Request-ID")] = request_id

      #api_endpoint = OMS::Configuration.get_telemetry_ods_endpoint.clone
      #api_endpoint.query = "api-version=#{@api_version}"
    
      agent_id =  OMS::Configuration.agent_id  
      #req = OMS::Common.create_ods_request(api_endpoint.request_uri, records, @compress, headers, lambda { |data| OMS::Common.safe_dump_simple_hash_array(data) })


      begin
        body_hb_xml =  AgentTopologyRequestHandler.new.handle_request(@os_info, @omsadmin_conf_path,
            agent_id, get_cert_server(@cert_path), @pid_path, telemetry=true)
      rescue => e
        log_error("Error when appending Telemetry to Heartbeat: #{e.message}")
      end

      # Form POST request and HTTP
      req,http = form_post_request_and_http(headers, "https://#{@WORKSPACE_ID}.oms.#{@URL_TLD}/"\
                "AgentService.svc/LinuxAgentTopologyRequest", body_hb_xml,
                OpenSSL::X509::Certificate.new(File.open(@cert_path)),
                OpenSSL::PKey::RSA.new(File.open(@key_path)))

      log_info("Generated heartbeat request:\n#{req.body}") if @verbose

      # Submit request
      begin
        res = nil
        res = http.start { |http_each| http.request(req) }
      rescue => e
        log_error("Error sending the heartbeat: #{e.message}")
      end

      if !res.nil?
        log_info("Heartbeat response code: #{res.code}") if @verbose

        if res.code == "200"
          log_info("Heartbeat success") if results == 0
          return results
        else
          log_error("Error sending the heartbeat. HTTP code #{res.code}")
          return 1
        end
      else
        log_error("Error sending the heartbeat. No HTTP code")
        return 1
      end


      #unless req.nil?
        #http = OMS::Common.create_ods_http(api_endpoint, @proxy_config)
        #OMS::Common.start_request(req, http)

        #return req.body.bytesize
      #end

      return 0
    end # post_data

    def get_user_agent
      user_agent = "LinuxMonitoringAgent/"
      #if file_exists_nonempty(@install_info)
      #  user_agent.concat(File.readlines(@install_info)[0].split.first)
      #end
      return user_agent
    end

    # Return the certificate text as a single formatted string
    def get_cert_server(cert_path)
      cert_server = ""

      cert_file_contents = File.readlines(cert_path)
      for i in 1..(cert_file_contents.length-2) #skip first and last line in file
        line = cert_file_contents[i]
        cert_server.concat(line[0..-2])
        if i < (cert_file_contents.length-2)
          cert_server.concat(" ")
        end
      end

      return cert_server
    end


    def form_post_request_and_http(headers, uri_string, body, cert, key)
      uri = URI.parse(uri_string)
      req = Net::HTTP::Post.new(uri.request_uri, headers)
      req.body = body

      http = OMS::Common.create_secure_http(uri, get_proxy_info)
      http.cert = cert
      http.key = key

      return req, http
    end


    # parse the tag to get the settings and append the message to blob
    # parameters:
    #   tag: string. the tag of the item
    #   records: hash[]. an arrary of data
    def handle_records(tag, records)
      @log.trace "Handling record : #{tag} x #{records.count}"
      tags = tag.split('.')
      if tags.size >= 3
        # tag should have 3 or 4 parts at least:
        # tags[0]: oms
        # tags[1]: api
        # tags[2]: log type
        # tags[3]: optional. name of the time generated field

        log_type = tags[2]
        time_generated_field_name = @time_generated_field

        # if the tag contains 4 parts, use tags[3] as the
        # time generated field name
        # otherwise, use the configure param value
        # whose default value is empty string
        if tags.size == 4
          time_generated_field_name = tags[3]
        end

        if @logtype_regex =~ log_type
          start = Time.now
          request_id = SecureRandom.uuid
          dataSize = post_data(log_type, time_generated_field_name, records, request_id)
          time = Time.now - start
          @log.trace "Success sending #{dataSize} bytes of data through API #{time.round(3)}s"
        else
          raise "The log type '#{log_type}' is not valid. it should match #{@logtype_regex}"
        end
      else
        raise "The tag does not have at least 3 parts #{tag}"
      end
    rescue OMS::RetryRequestException => e
      @log.info "Encountered retryable exception. Will retry sending data later."
      Log.error_once("Error for Request-ID: #{request_id} Error: #{e}")
      @log.debug "Error:'#{e}'"
      # Re-raise the exception to inform the fluentd engine we want to retry sending this chunk of data later.
      raise e.message, "Request-ID: #{request_id}"
    rescue => e
      # We encountered something unexpected. We drop the data because
      # if bad data caused the exception, the engine will continuously
      # try and fail to resend it. (Infinite failure loop)
      OMS::Log.error_once("Unexpected exception, dropping data. Error:'#{e}'")
    end # handle_record

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
      if !OMS::Configuration.load_configuration(omsadmin_conf_path, cert_path, key_path)
        raise 'Missing configuration. Make sure to onboard. Will continue to buffer data.'
      end

      # Group records based on their datatype because OMS does not support a single request with multiple datatypes.
      datatypes = {}
      chunk.msgpack_each {|(tag, record)|
        if !record.to_s.empty?
          if !datatypes.has_key?(tag)
            datatypes[tag] = []
          end

          if record.is_a?(Array)
            record.each do |r|
              datatypes[tag] << r if !r.to_s.empty? and r.is_a?(Hash)
            end
          elsif record.is_a?(Hash)
            datatypes[tag] << record
          end
        end
      }

      datatypes.each do |tag, records|
        handle_records(tag, records)
      end
    end

  end # Class

end # Module

