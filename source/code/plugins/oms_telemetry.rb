module OMS

  require_relative 'agent_topology_request_script'

  class AgentResourceUsage < StrongTypedClass
    strongtyped_accessor :OMSMaxMemory, Integer
    strongtyped_accessor :OMSMaxPercentMemory, Integer
    strongtyped_accessor :OMSMaxUserTime, Integer
    strongtyped_accessor :OMSMaxSystemTime, Integer
    strongtyped_accessor :OMSAvgMemory, Integer
    strongtyped_accessor :OMSAvgPercentMemory, Integer
    strongtyped_accessor :OMSAvgUserTime, Integer
    strongtyped_accessor :OMSAvgSystemTime, Integer
    strongtyped_accessor :OMIMaxMemory, Integer
    strongtyped_accessor :OMIMaxPercentMemory, Integer
    strongtyped_accessor :OMIMaxUserTime, Integer
    strongtyped_accessor :OMIMaxSystemTime, Integer
    strongtyped_accessor :OMIAvgMemory, Integer
    strongtyped_accessor :OMIAvgPercentMemory, Integer
    strongtyped_accessor :OMIAvgUserTime, Integer
    strongtyped_accessor :OMIAvgSystemTime, Integer
  end
  
  class AgentQoS < StrongTypedClass
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
  
  class Telemetry < StrongTypedClass
    
    require_relative 'oms_common'
    require_relative 'oms_configuration'
    
    strongtyped_accessor :WorkspaceId, String
    strongtyped_accessor :AgentId, String
    strongtyped_accessor :AgentVersion, String
    strongtyped_accessor :OSType, String
    strongtyped_accessor :OSDistro, String
    strongtyped_accessor :OSVersion, String
    strongtyped_accessor :IsAzure, Boolean
    strongtyped_accessor :Solutions, String
    strongtyped_accessor :ConfigMgrEnabled, Boolean
    strongtyped_accessor :ResourceUsage, AgentResourceUsage
    strongtyped_accessor :QoS, AgentQoS
    
    # Operation Types
    SEND_BATCH = "SendBatch"
    CREATE_BATCH = "CreateBatch"
    # ?

    SOURCE_MAP = {

    }

    # can add calls in         OMS::Common.start_request(req, http) or create_ods_request to call into this class

    # should record source (tag/datatyle), eventcount, size, latencies (3)
    @qos_events = []
    @ru_points = { omscpu: [], omsmem: [], omicpu: [], omimem: []}

    def push_qos_event(operation, operation_success, message, key, record)

    end # push_qos_event

    def poll_resource_usage()
      if ENV['TEST_WORKSPACE_ID'].nil? && ENV['TEST_SHARED_KEY'].nil? && File.exist?(conf_omsadmin)
       process_stats = ""
       # If there is no PID file, the omsagent process has not started, so no telemetry
       if File.exist?(pid_file) and File.readable?(pid_file)
         pid = File.read(pid_file)
         process_stats = `/opt/omi/bin/omicli wql root/scx \"SELECT PercentUserTime, PercentPrivilegedTime, UsedMemory, PercentUsedMemory FROM SCX_UnixProcessStatisticalInformation where Handle like '#{pid}'\" | grep =`
       end

       process_stats.each_line do |line|
         telemetry.PercentUserTime = line.sub("PercentUserTime=","").strip.to_i if line =~ /PercentUserTime/
         telemetry.PercentPrivilegedTime = line.sub("PercentPrivilegedTime=", "").strip.to_i if  line =~ /PercentPrivilegedTime/
         telemetry.UsedMemory = line.sub("UsedMemory=", "").strip.to_i if line =~ / UsedMemory/
         telemetry.PercentUsedMemory = line.sub("PercentUsedMemory=", "").strip.to_i if line =~ /PercentUsedMemory/
       end
    end # poll_resource_usage

    def aggregate_stats()

    end # aggregate_stats
  

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




















def get_telemetry_data(os_info, conf_omsadmin, pid_file)
  os = AgentTopologyRequestOperatingSystem.new
  telemetry = AgentTopologyRequestOperatingSystemTelemetry.new

  if !File.exist?(os_info) && !File.readable?(os_info)
    raise ArgumentError, " Unable to read file #{os_info}; telemetry information will not be sent to server"
  end

  if File.exist?('/var/opt/microsoft/docker-cimprov/state/containerhostname')
    os.InContainer = "True"
    containerimagetagfile = '/var/opt/microsoft/docker-cimprov/state/omscontainertag'
    if File.exist?(containerimagetagfile) && File.readable?(containerimagetagfile)
      os.InContainerVersion = File.read(containerimagetagfile)
    end
    if !ENV['AKS_RESOURCE_ID'].nil?
      os.IsAKSEnvironment = "True"
    end
    k8sversionfile = "/var/opt/microsoft/docker-cimprov/state/kubeletversion"
    if File.exist?(k8sversionfile) && File.readable?(k8sversionfile) 
      os.K8SVersion = File.read(k8sversionfile)
    end
  else
    os.InContainer = "False"
  end

  # Get process stats from omsagent for telemetry
  if ENV['TEST_WORKSPACE_ID'].nil? && ENV['TEST_SHARED_KEY'].nil? && File.exist?(conf_omsadmin)
    process_stats = ""
    # If there is no PID file, the omsagent process has not started, so no telemetry
    if File.exist?(pid_file) and File.readable?(pid_file)
      pid = File.read(pid_file)
      process_stats = `/opt/omi/bin/omicli wql root/scx \"SELECT PercentUserTime, PercentPrivilegedTime, UsedMemory, PercentUsedMemory FROM SCX_UnixProcessStatisticalInformation where Handle like '#{pid}'\" | grep =`
    end

    process_stats.each_line do |line|
      telemetry.PercentUserTime = line.sub("PercentUserTime=","").strip.to_i if line =~ /PercentUserTime/
      telemetry.PercentPrivilegedTime = line.sub("PercentPrivilegedTime=", "").strip.to_i if  line =~ /PercentPrivilegedTime/
      telemetry.UsedMemory = line.sub("UsedMemory=", "").strip.to_i if line =~ / UsedMemory/
      telemetry.PercentUsedMemory = line.sub("PercentUsedMemory=", "").strip.to_i if line =~ /PercentUsedMemory/
    end
  end