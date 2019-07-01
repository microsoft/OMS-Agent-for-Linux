module Fluent

  class OutputOMSDiag < BufferedOutput

    Plugin.register_output('out_oms_diag', self)

    def initialize
      super
      require 'net/http'
      require 'net/https'
      require 'uri'
      require_relative 'omslog'
      require_relative 'oms_configuration'
      require_relative 'oms_common'
      require_relative 'oms_diag_lib'
      require_relative 'agent_telemetry_script'
    end

    config_param :omsadmin_conf_path, :string, :default => '/etc/opt/microsoft/omsagent/conf/omsadmin.conf'
    config_param :cert_path, :string, :default => '/etc/opt/microsoft/omsagent/certs/oms.crt'
    config_param :key_path, :string, :default => '/etc/opt/microsoft/omsagent/certs/oms.key'
    config_param :proxy_conf_path, :string, :default => '/etc/opt/microsoft/omsagent/proxy.conf'
    config_param :compress, :bool, :default => true
    config_param :run_in_background, :bool, :default => false

    def configure(conf)
      super
    end

    def start
      super
      @proxy_config = OMS::Configuration.get_proxy_config(@proxy_conf_path)
    end

    def shutdown
      super
      OMS::BackgroundJobs.instance.cleanup
    end

    def handle_record(ipname, record)
      @log.trace "Handling diagnostic records for ipname : #{ipname}"
      req = OMS::Common.create_ods_request(OMS::Configuration.diagnostic_endpoint.path, record, @compress)
      unless req.nil?
        http = OMS::Common.create_ods_http(OMS::Configuration.diagnostic_endpoint, @proxy_config)
        start = Time.now

        # This method will raise on failure alerting the engine to retry sending this data
        OMS::Common.start_request(req, http)

        ends = Time.now
        time = ends - start
        count = record[OMS::Diag::RECORD_DATAITEMS].size
        @log.debug "Success sending diagnotic logs #{ipname} x #{count} in #{time.round(2)}s"
        return OMS::Telemetry.push_qos_event(OMS::SEND_BATCH, "true", "", ipname, record, count, time)
      end
    rescue OMS::RetryRequestException => e
      @log.info "Encountered retryable exception. Will retry sending diagnostic data later."
      @log.debug "Error with diagnostic log:'#{e}'"
      # Re-raise the exception to inform the fluentd engine we want to retry sending this chunk of data later.
      raise e.message
    rescue => e
      # We encountered something unexpected. We drop the data because
      # if bad data caused the exception, the engine will continuously
      # try and fail to resend it. (Infinite failure loop)
      msg = "Unexpected exception, dropping diagnostic data. Error:'#{e}'"
      OMS::Log.error_once(msg)
      return msg
    end

    # This method is called when an event reaches to Fluentd.
    # Convert the event to a raw string.
    def format(tag, time, record)
      if record != {}
        return record.to_msgpack
      else
        return ""
      end
    end

    def self_write(chunk)
      # ipname to dataitems array hash
      ipnameRecords = Hash.new

      # Aggregation based on ipname
      chunk.msgpack_each do |dataitem|
        ipname = OMS::Diag::DEFAULT_IPNAME
        if dataitem.is_a?(Hash)
          if dataitem.key?(OMS::Diag::DI_KEY_IPNAME)
            ipname = dataitem[OMS::Diag::DI_KEY_IPNAME]
          end
          if ipnameRecords.key?(ipname)
            ipnameRecords[ipname] << dataitem
          else
            ipnameRecords[ipname] = [dataitem]
          end
        end
      end

      # getting diag records out of aggregated dataitems for serialization
      ret = []
      ipnameRecords.each do |ipname, dataitemArray|
        OMS::Diag.ProcessDataItemsPostAggregation(dataitemArray, OMS::Configuration.agent_id)
        record = OMS::Diag.CreateDiagRecord(dataitemArray, ipname)
        ret << handle_record(ipname, records)
        ret << {'source': ipname, 'event':  handle_record(ipname, records)}
      end
      return ret
    end

    def write(chunk)
      # Quick exit if we are missing something
      if !OMS::Configuration.load_configuration(omsadmin_conf_path, cert_path, key_path)
        raise OMS::RetryRequestException, 'Missing configuration. Make sure to onboard.'
      end

      if run_in_background
        OMS::BackgroundJobs.instance.run_job_and_wait { self_write(chunk) }
      else
        self_write(chunk)
      end
    end

  end

end
