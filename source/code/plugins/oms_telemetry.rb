module OMS

  class AgentTelemetryRequest < StrongTypedClass

    require_relative 'agent_topology_request_script'

    strongtyped_accessor :WorkspaceId, String
    strongtyped_accessor :AgentId, String
    strongtyped_accessor :AgentVersion, String
    strongtyped_accessor :Operation, String
    strongtyped_accessor :OperationSuccess, Boolean
    strongtyped_accessor :Message, String
    strongtyped_accessor :Source, String
    strongtyped_accessor :BatchCount, Integer
    strongtyped_accessor :MinBatcheventCount, Integer
    strongtyped_accessor :MaxBatchEventCount, Integer
    strongtyped_accessor :AvgBatchEventCount, Integer
    strongtyped_accessor :MinBatchSize, Integer
    strongtyped_accessor :MaxBatchSize, Integer
    strongtyped_accessor :AvgBatchSize, Integer
    strongtyped_accessor :MinLocalLatency, Integer
    strongtyped_accessor :MaxLocalLatency, Integer
    strongtyped_accessor :AvgLocalLatency, Integer
  end

  class Telemetry

    require_relative 'oms_common'
    require_relative 'oms_configuration'

    # Operation Types
    SEND_BATCH = "SendBatch"
    CREATE_BATCH = "CreateBatch"
    # ?

    SOURCE_MAP = {

    }

    # can add calls in         OMS::Common.start_request(req, http) or create_ods_request to call into this class

    # should record source (tag/datatyle), eventcount, size, latencies (3)
    @@qos_events = []

    def push_qos_event(operation, operation_success, message, key, record)

    end # push_qos_event


    def aggregate_stats()

    end # aggregate_stats


    def send_qos()
      telemetry = AgentTelemetryRequest.new
      
      # null checking?
      telemetry.WorkspaceId = OMS::Configuration.workspace_id
      telemetry.AgentId = OMS::Configuration.agent_id
      telemetry.AgentVersion = OMS::Common.get_agent_version

      

    end # send_qos

  end # class Telemetry

end # module OMS




def heartbeat
  # Reload config in case of updates since last topology request
  @load_config_return_code = load_config
  if @load_config_return_code != 0
    log_error("Error loading configuration from #{@omsadmin_conf_path}")
    return @load_config_return_code
  end

  # Check necessary inputs
  if @WORKSPACE_ID.nil? or @AGENT_GUID.nil? or @URL_TLD.nil? or
      @WORKSPACE_ID.empty? or @AGENT_GUID.empty? or @URL_TLD.empty?
    log_error("Missing required field from configuration file: #{@omsadmin_conf_path}")
    return MISSING_CONFIG
  elsif !file_exists_nonempty(@cert_path) or !file_exists_nonempty(@key_path)
    log_error("Certificates for topology request do not exist")
    return MISSING_CERTS
  end

  # Generate the request body
  begin
    body_hb_xml = AgentTopologyRequestHandler.new.handle_request(@os_info, @omsadmin_conf_path,
        @AGENT_GUID, get_cert_server(@cert_path), @pid_path, telemetry=true)
    if !xml_contains_telemetry(body_hb_xml)
      log_debug("No Telemetry data was appended to OMS agent management service topology request")
    end
  rescue => e
    log_error("Error when appending Telemetry to OMS agent management service topology request: #{e.message}")
  end

  # Form headers
  headers = {}
  req_date = Time.now.utc.strftime("%Y-%m-%dT%T.%N%:z")
  headers[OMS::CaseSensitiveString.new("x-ms-Date")] = req_date
  headers["User-Agent"] = get_user_agent
  headers[OMS::CaseSensitiveString.new("Accept-Language")] = "en-US"

  # Form POST request and HTTP
  req,http = form_post_request_and_http(headers, "https://#{@WORKSPACE_ID}.oms.#{@URL_TLD}/"\
            "AgentService.svc/LinuxAgentTopologyRequest", body_hb_xml,
            OpenSSL::X509::Certificate.new(File.open(@cert_path)),
            OpenSSL::PKey::RSA.new(File.open(@key_path)))

  log_info("Generated topology request:\n#{req.body}") if @verbose

  # Submit request
  begin
    res = nil
    res = http.start { |http_each| http.request(req) }
  rescue => e
    log_error("Error sending the topology request to OMS agent management service: #{e.message}")
  end

  if !res.nil?
    log_info("OMS agent management service topology request response code: #{res.code}") if @verbose

    if res.code == "200"
      cert_apply_res = apply_certificate_update_endpoint(res.body)
      dsc_apply_res = apply_dsc_endpoint(res.body)
      if cert_apply_res.class != String
        return cert_apply_res
      elsif dsc_apply_res.class != String
        return dsc_apply_res
      else
        log_info("OMS agent management service topology request success")
        return 0
      end
    else
      log_error("Error sending OMS agent management service topology request . HTTP code #{res.code}")
      return HTTP_NON_200
    end
  else
    log_error("Error sending OMS agent management service topology request . No HTTP code")
    return ERROR_SENDING_HTTP
  end
end