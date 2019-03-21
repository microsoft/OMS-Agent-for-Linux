require 'optparse'

module OMS

  require_relative 'agent_topology_request_script'

  # Operation Types
  SEND_BATCH = "SendBatch"
  CREATE_BATCH = "CreateBatch"

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
    strongtyped_accessor :OperationSuccess, String
    strongtyped_accessor :Message, String
    strongtyped_accessor :Source, String
    strongtyped_accessor :BatchCount, Integer
    strongtyped_accessor :MinBatchEventCount, Integer
    strongtyped_accessor :MaxBatchEventCount, Integer
    strongtyped_accessor :AvgBatchEventCount, Integer
    strongtyped_accessor :MinBatchSize, Integer
    strongtyped_accessor :MaxBatchSize, Integer
    strongtyped_accessor :AvgBatchSize, Integer
    strongtyped_accessor :MinLocalLatency, Integer
    strongtyped_accessor :MaxLocalLatency, Integer
    strongtyped_accessor :AvgLocalLatency, Integer
    strongtyped_accessor :NetworkLatency, Integer
  end

  class AgentTelemetry < StrongTypedClass
    strongtyped_accessor :OSType, String
    strongtyped_accessor :OSDistro, String
    strongtyped_accessor :OSVersion, String
    strongtyped_accessor :Region, String
    strongtyped_accessor :ConfigMgrEnabled, String
    strongtyped_accessor :ResourceUsage, AgentResourceUsage
    strongtyped_accessor :QoS, Array # of AgentQoS
  end
  
  class Telemetry

    require 'json'
    require 'objspace'

    require_relative 'omslog'
    require_relative 'oms_common'
    require_relative 'oms_configuration'
    require_relative 'agent_maintenance_script'

    @@qos_events = {}

    def initialize(omsadmin_conf_path, cert_path, key_path, pid_path, proxy_path, os_info, install_info, log, verbose)
      @pids = {oms: 0, omi: 0}
      @ru_points = {oms: {usr_cpu: [], sys_cpu: [], amt_mem: [], pct_mem: []},
                    omi: {usr_cpu: [], sys_cpu: [], amt_mem: [], pct_mem: []}}

      @omsadmin_conf_path = omsadmin_conf_path
      @cert_path = cert_path
      @key_path = key_path
      @pid_path = pid_path
      @proxy_path = proxy_path
      @os_info = os_info
      @install_info = install_info
      @log = log ? log : OMS::Common.get_logger(log)
      @verbose = true # verbose
      @workspace_id = nil
      @agent_guid = nil
      @url_tld = nil
    end # initialize

    # Logging methods
    def log_info(message)
      print("info\t#{message}\n") if !@suppress_logging
      @log.info(message) if !@suppress_logging
    end

    def log_error(message)
      print("error\t#{message}\n") if !@suppress_logging
      @log.error(message) if !@suppress_logging
    end

    def log_debug(message)
      print("debug\t#{message}\n") if !@suppress_logging
      @log.debug(message) if !@suppress_logging
    end

    def load_config
      if !File.exist?(@omsadmin_conf_path)
        log_error("Missing configuration file: #{@omsadmin_conf_path}")
        return OMS::MISSING_CONFIG_FILE
      end

      File.open(@omsadmin_conf_path, "r").each_line do |line|
        if line =~ /^WORKSPACE_ID/
          @workspace_id = line.sub("WORKSPACE_ID=","").strip
        elsif line =~ /^AGENT_GUID/
          @agent_guid = line.sub("AGENT_GUID=","").strip
        elsif line =~ /^URL_TLD/
          @url_tld = line.sub("URL_TLD=","").strip
        end
      end

      return 0
    end

    # Must be a class method in order to be exposed to all out_*.rb pushing qos events
    def self.push_qos_event(operation, operation_success, message, source, batch, count, time)
      event = { op: operation, op_success: operation_success, m: message, s: ObjectSpace.memsize_of(batch), c: count, t: time }
      # event[:s] = ObjectSpace.memsize_of(batch)
      if batch.is_a? Array # custom log record is simply an array
        # can't really do anything
      elsif batch.is_a? Hash and batch.has_key?('DataItems') and batch['DataItems'][0].has_key?('Timestamp')
        records = batch['DataItems']
        OMS::Log.warn_once(records[0]['Timestamp'].class.to_s)
        now = Time.now
        times = records.map { |record| now - Time.parse(record['Timestamp']) }
        event[:min_l] = times[-1] # records appear in order, so last record will have lowest latency
        event[:max_l] = times[0]
        event[:sum_l] = times.sum
      else
        # maybe don't do anything?
      end

      if @@qos_events.has_key?(source)
        @@qos_events[source] << event
      else
        @@qos_events[source] = [event]
      end
      OMS::Log.warn_once(event.to_json)
      # OMS::Log.warn_once(batch.to_json)
    end # push_qos_event

    def get_pids()
      @pids.each do |key, value|
        case key
        when :oms
          if File.exist?(@pid_path) and File.readable?(@pid_path)
            @pids[key] = File.read(@pid_path).to_i
          end
        when :omi
          @pids[key] = `pgrep -U omsagent omiagent`.to_i
        end
      end
    end

    def poll_resource_usage()
      get_pids
      command = "/opt/omi/bin/omicli wql root/scx \"SELECT PercentUserTime, PercentPrivilegedTime, UsedMemory, "\
                "PercentUsedMemory FROM SCX_UnixProcessStatisticalInformation where Handle like '%s'\" | grep ="

      if ENV['TEST_WORKSPACE_ID'].nil? && ENV['TEST_SHARED_KEY'].nil? && File.exist?(@omsadmin_conf_path)
        @pids.each do |key, value|
          if !value.zero?
            `#{command % value}`.each_line do |line|
              @ru_points[key][:usr_cpu] << line.sub("PercentUserTime=","").strip.to_i if line =~ /PercentUserTime/
              @ru_points[key][:sys_cpu] << line.sub("PercentPrivilegedTime=", "").strip.to_i if  line =~ /PercentPrivilegedTime/
              @ru_points[key][:amt_mem] << line.sub("UsedMemory=", "").strip.to_i if line =~ / UsedMemory/
              @ru_points[key][:pct_mem] << line.sub("PercentUsedMemory=", "").strip.to_i if line =~ /PercentUsedMemory/
            end
          else # pad with zeros when OMI might not be running
            @ru_points[key][:usr_cpu] << 0
            @ru_points[key][:sys_cpu] << 0
            @ru_points[key][:amt_mem] << 0
            @ru_points[key][:pct_mem] << 0
          end
        end
      end
    end # poll_resource_usage

    def array_avg(array)
      return (array.reduce(:+) / array.size.to_f).to_i
    end # array_avg

    def calculate_resource_usage()
      resource_usage = AgentResourceUsage.new
      resource_usage.OMSMaxMemory        = @ru_points[:oms][:amt_mem].max
      resource_usage.OMSMaxPercentMemory = @ru_points[:oms][:pct_mem].max
      resource_usage.OMSMaxUserTime      = @ru_points[:oms][:usr_cpu].max
      resource_usage.OMSMaxSystemTime    = @ru_points[:oms][:sys_cpu].max
      resource_usage.OMSAvgMemory        = array_avg(@ru_points[:oms][:amt_mem])
      resource_usage.OMSAvgPercentMemory = array_avg(@ru_points[:oms][:pct_mem])
      resource_usage.OMSAvgUserTime      = array_avg(@ru_points[:oms][:usr_cpu])
      resource_usage.OMSAvgSystemTime    = array_avg(@ru_points[:oms][:sys_cpu])
      resource_usage.OMIMaxMemory        = @ru_points[:omi][:amt_mem].max
      resource_usage.OMIMaxPercentMemory = @ru_points[:omi][:pct_mem].max
      resource_usage.OMIMaxUserTime      = @ru_points[:omi][:usr_cpu].max
      resource_usage.OMIMaxSystemTime    = @ru_points[:omi][:sys_cpu].max
      resource_usage.OMIAvgMemory        = array_avg(@ru_points[:omi][:amt_mem])
      resource_usage.OMIAvgPercentMemory = array_avg(@ru_points[:omi][:pct_mem])
      resource_usage.OMIAvgUserTime      = array_avg(@ru_points[:omi][:usr_cpu])
      resource_usage.OMIAvgSystemTime    = array_avg(@ru_points[:omi][:sys_cpu])
      return resource_usage
    end

    def calculate_qos()
      # for now, since we are only instrumented to emit upload success, only merge based on source

      qos = []
      @@qos_events.each do |source, events|
        qos_event = AgentQoS.new
        qos_event.Source = source
        qos_event.Message = events[0][:m]
        qos_event.OperationSuccess = events[0][:op_success]
        qos_event.BatchCount = events.size
        qos_event.Operation = event[:op]

        counts = events.map { |event| event[:c] }
        qos_event.MinBatchEventCount = counts.min
        qos_event.MaxBatchEventCount = counts.max
        qos_event.AvgBatchEventCount = counts.sum / counts.size

        size = events.map { |event| event[:s] }
        qos_event.MinBatchSize = size.min
        qos_event.MaxBatchSize = size.max
        qos_event.AvgBatchSize = size.sum / size.sum

        qos_event.MinLocalLatency = event[-1][:min_l]
        qos_event.MaxLocalLatency = event[0][:max_l]
        qos_event.AvgLocalLatency = (events.map{ |event| event[:sum_l] }).sum / counts.sum

        qos_event.NetworkLatency = (events.map { |event| event[:t] }).sum / events.size
      end

      return qos
    end

    def create_body()
      agent_telemetry = AgentTelemetry.new
      agent_telemetry.OSType = "Linux"
      File.open(@os_info).each_line do |line|
        agent_telemetry.OSDistro = line.sub("OSName=","").strip if line =~ /OSName/
        agent_telemetry.OSVersion = line.sub("OSVersion=","").strip if line =~ /OSVersion/
      end
      agent_telemetry.Region = OMS::Configuration.azure_region
      agent_telemetry.ConfigMgrEnabled = File.exist?("/etc/opt/omi/conf/omsconfig/omshelper_disable").to_s
      agent_telemetry.ResourceUsage = calculate_resource_usage
      agent_telemetry.QoS = calculate_qos
      log_info(agent_telemetry.inspect)
      return agent_telemetry
    end

    def heartbeat()
      log_error("Agent Telemetry Script Heartbeat.")

      # Reload config in case of updates since last topology request
      @load_config_return_code = load_config
      if @load_config_return_code != 0
        log_error("Error loading configuration from #{@omsadmin_conf_path}")
        return @load_config_return_code
      end

      # Check necessary inputs
      if @workspace_id.nil? or @agent_guid.nil? or @url_tld.nil? or
        @workspace_id.empty? or @agent_guid.empty? or @url_tld.empty?
        log_error("Missing required field from configuration file: #{@omsadmin_conf_path}")
        return OMS::MISSING_CONFIG
      elsif !OMS::Common.file_exists_nonempty(@cert_path) or !OMS::Common.file_exists_nonempty(@key_path)
        log_error("Certificates for topology request do not exist")
        return OMS::MISSING_CERTS
      end

      # Generate the request body
      body = create_body.to_json

      # Form headers
      headers = {}
      req_date = Time.now.utc.strftime("%Y-%m-%dT%T.%N%:z")
      headers[OMS::CaseSensitiveString.new("x-ms-Date")] = req_date
      headers["User-Agent"] = "LinuxMonitoringAgent".concat(OMS::Common.get_agent_version)
      headers[OMS::CaseSensitiveString.new("Accept-Language")] = "en-US"

      # Form POST request and HTTP
      uri = "https://#{@workspace_id}.oms.#{@url_tld}/AgentService.svc/AgentTelemetry"
      req,http = OMS::Common.form_post_request_and_http(headers, uri, body,
                      OpenSSL::X509::Certificate.new(File.open(@cert_path)),
                      OpenSSL::PKey::RSA.new(File.open(@key_path)), @proxy_path)
      
      log_info("Generated telemetry request:\n#{req.body}") if @verbose

      # Submit request
      begin
        res = nil
        res = http.start { |http_each| http.request(req) }
      rescue => e
        log_error("Error sending the telemetry request to OMS agent management service: #{e.message}")
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
          return OMS::HTTP_NON_200
        end
      else
        log_error("Error sending OMS agent management service topology request . No HTTP code")
        return OMS::ERROR_SENDING_HTTP
      end

      # clear arrays
    end # heartbeat

  end # class Telemetry
end # module OMS

# Define the usage of this telemetry script
def usage
  basename = File.basename($0)
  necessary_inputs = "<omsadmin_conf> <cert> <key> <pid> <proxy> <os_info> <install_info>"
  print("\nTelemetry tool for OMS Agent\n"\
        "ruby #{basename} #{necessary_inputs}\n"\
        "\nOptional: Add -v for verbose output\n")
end

if __FILE__ == $0
  options = {}
  OptionParser.new do |opts|
    opts.on("-v", "--verbose") do |v|
      options[:verbose] = true
    end
  end.parse!

  if (ARGV.length < 7)
    usage
    exit 0
  end

  omsadmin_conf_path = ARGV[0]
  cert_path = ARGV[1]
  key_path = ARGV[2]
  pid_path = ARGV[3]
  proxy_path = ARGV[4]
  os_info = ARGV[5]
  install_info = ARGV[6]

  telemetry = OMS::Telemetry.new(omsadmin_conf_path, cert_path, key_path,
                    pid_path, proxy_path, os_info, install_info, log = nil, options[:verbose])

  OMS::Configuration.load_configuration(omsadmin_conf_path, cert_path, key_path)

  telemetry.poll_resource_usage
  telemetry.heartbeat

  exit 0
end