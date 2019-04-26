require 'optparse'

module OMS

  require_relative 'agent_common'

  # Operation Types
  SEND_BATCH = "SendBatch"

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
    strongtyped_accessor :MinEventSize, Integer
    strongtyped_accessor :MaxEventSize, Integer
    strongtyped_accessor :AvgEventSize, Integer
    strongtyped_accessor :MinLocalLatencyInMs, Integer
    strongtyped_accessor :MaxLocalLatencyInMs, Integer
    strongtyped_accessor :AvgLocalLatencyInMs, Integer
    strongtyped_accessor :NetworkLatencyInMs, Integer
  end

  class AgentTelemetry < StrongTypedClass
    strongtyped_accessor :OSType, String
    strongtyped_accessor :OSDistro, String
    strongtyped_accessor :OSVersion, String
    strongtyped_accessor :Region, String
    strongtyped_accessor :ConfigMgrEnabled, String
    strongtyped_accessor :AgentResourceUsage, AgentResourceUsage
    strongtyped_accessor :AgentQoS, Array # of AgentQoS

    def serialize
      qos_hash = self.AgentQoS.map! { |qos| obj_to_hash(qos) }
      hash = obj_to_hash(self)
      hash["AgentQoS"] = qos_hash
      return hash.to_json
    end
  end

  class Telemetry

    require 'json'

    require_relative 'omslog'
    require_relative 'oms_common'
    require_relative 'oms_configuration'
    require_relative 'agent_maintenance_script'

    attr_reader :ru_points
    attr_accessor :suppress_stdout

    QOS_EVENTS_LIMIT = 1000

    @@qos_events = {}

    def initialize(omsadmin_conf_path, cert_path, key_path, pid_path, proxy_path, os_info, install_info, log = nil, verbose = false)
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

      @load_config_return_code = OMS::Configuration.load_configuration(@omsadmin_conf_path, @cert_path, @key_path)

      @workspace_id = OMS::Configuration.workspace_id
      @agent_guid = OMS::Configuration.agent_guid
      @url_tld = OMS::Configuration.url_tld
      @log_facility = OMS::Configuration.log_facility

      @log = log.nil? ? OMS::Common.get_logger(@log_facility) : log
      @verbose = verbose

      @suppress_stdout = false
      @suppress_logging = false
    end # initialize

    # Logging methods
    def log_info(message)
      print("info\t#{message}\n") if !@suppress_logging and !@suppress_stdout
      @log.info(message) if !@suppress_logging
    end

    def log_error(message)
      print("error\t#{message}\n") if !@suppress_logging and !@suppress_stdout
      @log.error(message) if !@suppress_logging
    end

    def log_debug(message)
      print("debug\t#{message}\n") if !@suppress_logging and !@suppress_stdout
      @log.debug(message) if !@suppress_logging
    end

    # Must be a class method in order to be exposed to all out_*.rb pushing qos events
    def self.push_qos_event(operation, operation_success, message, source, batch, count, time)
      begin
        event = { op: operation, op_success: operation_success, m: message, c: count, t: time }
        if batch.is_a? Hash and batch.has_key?('DataItems')
          records = batch['DataItems']
          if batch['DataItems'][0].has_key?('Timestamp')
            now = Time.now
            times = records.map { |record| now - Time.parse(record['Timestamp']) }
            event[:min_l] = times[-1] # Records appear in order, so last record will have lowest latency
            event[:max_l] = times[0]
            event[:sum_l] = times.sum
          end
          sizes = records.map { |record| OMS::Common.parse_json_record_encoding(record) }.compact.map(&:bytesize) # Remove possible nil entries with compact
        elsif batch.is_a? Array
          # These other logs, such as custom logs, don't have a parsed timestamp
          sizes = batch.map { |record| OMS::Common.parse_json_record_encoding(record) }.compact.map(&:bytesize)
        else
          return
        end

        event[:min_s] = sizes.min
        event[:max_s] = sizes.max
        event[:sum_s] = sizes.sum

        if @@qos_events.has_key?(source)
          if @@qos_events[source].size >= QOS_EVENTS_LIMIT
            @@qos_events[source].shift # remove oldest qos event to cap memory use
          end
          @@qos_events[source] << event
        else
          @@qos_events[source] = [event]
        end
      rescue => e
        OMS::Log.error_once("Error pushing QoS event. #{e}")
      end
    end # push_qos_event

    def self.array_avg(array)
      if array.empty?
        return 0
      else
        return (array.reduce(0, :+) / array.size.to_f).to_i
      end
    end # array_avg

    def get_pids()
      @pids.each do |key, value|
        case key
        when :oms
          begin
            if File.exist?(@pid_path) and File.readable?(@pid_path)
              @pids[key] = File.read(@pid_path).to_i
            end
          rescue => e
            log_error("Error reading omsagent pid file. #{e}")
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
      begin
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
      rescue => e
        log_error("Error polling resource usage. #{e}")
      end
    end # poll_resource_usage

    def calculate_resource_usage()
      begin
        resource_usage = AgentResourceUsage.new
        resource_usage.OMSMaxMemory        = @ru_points[:oms][:amt_mem].max
        resource_usage.OMSMaxPercentMemory = @ru_points[:oms][:pct_mem].max
        resource_usage.OMSMaxUserTime      = @ru_points[:oms][:usr_cpu].max
        resource_usage.OMSMaxSystemTime    = @ru_points[:oms][:sys_cpu].max
        resource_usage.OMSAvgMemory        = Telemetry.array_avg(@ru_points[:oms][:amt_mem])
        resource_usage.OMSAvgPercentMemory = Telemetry.array_avg(@ru_points[:oms][:pct_mem])
        resource_usage.OMSAvgUserTime      = Telemetry.array_avg(@ru_points[:oms][:usr_cpu])
        resource_usage.OMSAvgSystemTime    = Telemetry.array_avg(@ru_points[:oms][:sys_cpu])
        resource_usage.OMIMaxMemory        = @ru_points[:omi][:amt_mem].max
        resource_usage.OMIMaxPercentMemory = @ru_points[:omi][:pct_mem].max
        resource_usage.OMIMaxUserTime      = @ru_points[:omi][:usr_cpu].max
        resource_usage.OMIMaxSystemTime    = @ru_points[:omi][:sys_cpu].max
        resource_usage.OMIAvgMemory        = Telemetry.array_avg(@ru_points[:omi][:amt_mem])
        resource_usage.OMIAvgPercentMemory = Telemetry.array_avg(@ru_points[:omi][:pct_mem])
        resource_usage.OMIAvgUserTime      = Telemetry.array_avg(@ru_points[:omi][:usr_cpu])
        resource_usage.OMIAvgSystemTime    = Telemetry.array_avg(@ru_points[:omi][:sys_cpu])
        clear_ru_points
        return resource_usage
      rescue => e
        log_error("Error calculating resource usage. #{e}")
        return nil
      end
    end

    def clear_ru_points
      @ru_points.each do |process, metrics|
        metrics.each do |key, value|
          value.clear
        end
      end
    end

    def calculate_qos()
      # for now, since we are only instrumented to emit upload success, only merge based on source
      qos = []

      begin
        @@qos_events.each do |source, batches|
          qos_event = AgentQoS.new
          qos_event.Source = source
          qos_event.Message = batches[0][:m]
          qos_event.OperationSuccess = batches[0][:op_success]
          qos_event.BatchCount = batches.size
          qos_event.Operation = batches[0][:op]

          counts = batches.map { |batch| batch[:c] }
          qos_event.MinBatchEventCount = counts.min
          qos_event.MaxBatchEventCount = counts.max
          qos_event.AvgBatchEventCount = Telemetry.array_avg(counts)

          qos_event.MinEventSize = batches.map { |batch| batch[:min_s] }.min
          qos_event.MaxEventSize = batches.map { |batch| batch[:max_s] }.max
          qos_event.AvgEventSize = batches.map { |batch| batch[:sum_s] }.sum / counts.sum

          if batches[0].has_key? :min_l
            qos_event.MinLocalLatencyInMs = (batches[-1][:min_l] * 1000).to_i # Latest batch will have smallest minimum latency
            qos_event.MaxLocalLatencyInMs = (batches[0][:max_l] * 1000).to_i
            qos_event.AvgLocalLatencyInMs = (((batches.map { |batch| batch[:sum_l] }).sum / counts.sum.to_f) * 1000).to_i
          else
            qos_event.MinLocalLatencyInMs = 0
            qos_event.MaxLocalLatencyInMs = 0
            qos_event.AvgLocalLatencyInMs = 0
          end

          qos_event.NetworkLatencyInMs = (((batches.map { |batch| batch[:t] }).sum / batches.size.to_f) * 1000).to_i # average

          qos << qos_event
        end
      rescue => e
        log_error("Error calculating QoS. #{e}")
        return nil
      end

      @@qos_events.clear
      return qos
    end

    def create_body()
      begin
        agent_telemetry = AgentTelemetry.new
        agent_telemetry.OSType = "Linux"
        File.open(@os_info).each_line do |line|
          agent_telemetry.OSDistro = line.sub("OSName=","").strip if line =~ /OSName/
          agent_telemetry.OSVersion = line.sub("OSVersion=","").strip if line =~ /OSVersion/
        end
        agent_telemetry.Region = OMS::Configuration.azure_region
        agent_telemetry.ConfigMgrEnabled = File.exist?("/etc/opt/omi/conf/omsconfig/omshelper_disable").to_s
        agent_telemetry.AgentResourceUsage = calculate_resource_usage
        agent_telemetry.AgentQoS = calculate_qos
        return (!agent_telemetry.AgentResourceUsage.nil? and !agent_telemetry.AgentQoS.nil?) ? agent_telemetry : nil
      rescue => e
        log_error("Error creating telemetry request body. #{e}")
        return nil
      end
    end

    def heartbeat()
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
      body = create_body
      return if body.nil?
      body = body.serialize

      # Form headers
      headers = {}
      req_date = Time.now.utc.strftime("%Y-%m-%dT%T.%N%:z")
      headers[OMS::CaseSensitiveString.new("x-ms-Date")] = req_date
      headers["User-Agent"] = "LinuxMonitoringAgent/".concat(OMS::Common.get_agent_version)
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
        log_info("OMS agent management service telemetry request response code: #{res.code}") if @verbose
      
        if res.code == "200"
          log_info("OMS agent management service telemetry request success")
          return 0
        else
          log_error("Error sending OMS agent management service telemetry request. HTTP code #{res.code}")
          return OMS::HTTP_NON_200
        end
      else
        log_error("Error sending OMS agent management service telemetry request. No HTTP code")
        return OMS::ERROR_SENDING_HTTP
      end
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

  require 'fluent/log'
  require 'fluent/engine'
  
  $log = Fluent::Log.new(STDERR, Fluent::Log::LEVEL_TRACE)

  telemetry = OMS::Telemetry.new(omsadmin_conf_path, cert_path, key_path,
                    pid_path, proxy_path, os_info, install_info, log = nil, options[:verbose])

  telemetry.poll_resource_usage
  telemetry.heartbeat

  exit 0
end