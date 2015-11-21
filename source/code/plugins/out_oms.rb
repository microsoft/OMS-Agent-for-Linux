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
      require_relative 'oms_configuration'
      require_relative 'oms_common'
    end

    config_param :omsadmin_conf_path, :string, :default => '/etc/opt/microsoft/omsagent/conf/omsadmin.conf'
    config_param :cert_path, :string, :default => '/etc/opt/microsoft/omsagent/certs/oms.crt'
    config_param :key_path, :string, :default => '/etc/opt/microsoft/omsagent/certs/oms.key'

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
      req = OMS::Common.create_ods_request(OMS::Configuration.ods_endpoint.path, record)
      start = Time.now
      
      OMS::Common.start_request(req, OMS::Common.create_ods_http(OMS::Configuration.ods_endpoint))
      
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
      if !OMS::Configuration.load_configuration(omsadmin_conf_path, cert_path, key_path)
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
