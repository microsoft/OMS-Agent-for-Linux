module Fluent

  class OutputSCOM < BufferedOutput

    Plugin.register_output('out_scom', self)

    def initialize
      super
      require 'net/http'
      require 'net/https'
      require 'uri'
      require_relative 'omslog'
      require_relative 'scom_configuration'
      require_relative 'scom_common'
      require_relative 'agent_telemetry_script'
    end

    desc 'Parameter to enable/disable SCOM server authentication'
    config_param :enable_server_auth, :bool, :default => true

    def configure(conf)
      super
    end

    def start
      super
    end

    def shutdown
      super
    end

    def handle_record(tag, record)
      @log.trace "Handling record with tag #{tag} #{record}"
      scom_endpoint = nil
      if record.has_key? 'CustomEvents'
        scom_endpoint = SCOM::Configuration.scom_event_endpoint
      elsif record.has_key? 'PerformanceDataList'
        scom_endpoint = SCOM::Configuration.scom_perf_endpoint
      else
        raise 'Invalid Record: #{record}'
      end
      @log.debug "SCOM endpoint: #{scom_endpoint}" 
      req = SCOM::Common.create_request(scom_endpoint.path, record)
      unless req.nil?
        http = SCOM::Common.create_http(scom_endpoint)
        start = Time.now
          
        # This method will raise on failure alerting the engine to retry sending this data
        SCOM::Common.start_request(req, http)
          
        ends = Time.now
        time = ends - start
        @log.debug "Success sending #{tag} in #{time.round(2)}s"
        OMS::Telemetry.push_qos_event(OMS::SEND_BATCH, "true", "", tag, record, record.size, time)
        return true
      end
    rescue SCOM::RetryRequestException => e
      @log.info "Encountered retryable exception. Will retry sending data later."
      @log.debug "Error:'#{e}'"
      # Re-raise the exception to inform the fluentd engine we want to retry sending this chunk of data later.
      raise e.message
    rescue => e
      OMS::Log.error_once("Unexpected exception, dropping record #{record}. Error:'#{e}'")
    end

    # This method is called when an event reaches to Fluentd.
    # Convert the event to a raw string.
    def format(tag, time, record)
      if (record != {}) && ((record.has_key? 'CustomEvents') || (record.has_key? 'PerformanceDataList'))
        @log.trace "Buffering #{tag}"
        return [tag, record].to_msgpack
      else
        return ""
      end
    end

    # This method is called every flush interval.
    # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
    def write(chunk)
      # Quick exit if we are missing something
      if !SCOM::Configuration.load_scom_configuration(@enable_server_auth)
        raise SCOM::RetryRequestException, 'Missing configuration. Make sure to run discovery.'
      end
      @log.trace "Writing chunk"
      #TBD: Club similar records before sending to SCOM server
      chunk.msgpack_each do |(tag, record)|
        handle_record(tag, record)
      end
    end

  end # class OutputSCOM

end # module Fluent
