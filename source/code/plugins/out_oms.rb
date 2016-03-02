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
    config_param :proxy_conf_path, :string, :default => '/etc/opt/microsoft/omsagent/conf/proxy.conf'
    config_param :compress, :bool, :default => true

    def configure(conf)
      s = conf.add_element("secondary")
      s["type"] = ChunkErrorHandler::SecondaryName
      super
    end

    def start
      super
      @proxy_config = OMS::Configuration.get_proxy_config(@proxy_conf_path)
    end

    def shutdown
      super
    end

    def handle_record(tag, record)
      req = OMS::Common.create_ods_request(OMS::Configuration.ods_endpoint.path, record, @compress)
      unless req.nil?
        http = OMS::Common.create_ods_http(OMS::Configuration.ods_endpoint, @proxy_config)
        start = Time.now
          
        # This method will raise on failure alerting the engine to retry sending this data
        OMS::Common.start_request(req, http)
          
        ends = Time.now
        time = ends - start
        count = record.has_key?('DataItems') ? record['DataItems'].size : 1
        @log.debug "Success sending #{tag} x #{count} in #{time.round(2)}s"
      end  
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

      datatypes.each do |tag, record|
        handle_record(tag, record)
      end

      @log.trace "Handling #{unmergable_records.size} unmergeable records"
      unmergable_records.each { |tag, record|
        handle_record(tag, record)
      }
    end

  private

    class ChunkErrorHandler
      include Configurable
      include PluginId
      include PluginLoggerMixin

      SecondaryName = "__ChunkErrorHandler__"

      Plugin.register_output(SecondaryName, self)

      def initialize
        @router = nil
      end

      def secondary_init(primary)
        @error_handlers = create_error_handlers @router
      end

      def start
        # NOP
      end

      def shutdown
        # NOP
      end

      def router=(r)
        @router = r
      end

      def write(chunk)
        chunk.msgpack_each {|(tag, record)|
          @error_handlers[tag].emit(record)
        }
    end
   
    private

      def create_error_handlers(router)
        nop_handler = NopErrorHandler.new
        Hash.new() { |hash, tag|
          etag = OMS::Common.create_error_tag tag
          hash[tag] = router.match?(etag) ?
                      ErrorHandler.new(router, etag) :
                      nop_handler
        }
      end

      class ErrorHandler
        def initialize(router, etag)
          @router = router
          @etag = etag
        end

        def emit(record)
          @router.emit(@etag, Fluent::Engine.now, record)
        end
      end

      class NopErrorHandler
        def emit(record)
          # NOP
        end
      end

    end

  end # class OutputOMS

end # module Fluent
