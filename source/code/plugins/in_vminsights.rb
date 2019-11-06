# frozen_string_literal: true


class Fluent::VMInsights < Fluent::Input
    require_relative 'oms_common'

    require_relative 'VMInsightsDataCollector.rb'
    require_relative 'VMInsightsEngine.rb'

    Fluent::Plugin.register_input('vminsights', self)

    config_param :tag, :string
    config_param :poll_interval, :integer, :default => 60

    def initialize
        super
        @instance_id = self.class.name + "(" + Time.now.to_s + ")"
    end

    def configure(conf)
        super

        begin
            @log = LogWrapper.new(LogPrefix, @log) unless @log.kind_of? LogWrapper
            @heartbeat_uploader = conf[:MockMetricsEngine] || ::VMInsights::MetricsEngine.new
            @heartbeat_upload_configuration = make_heartbeat_configuration
        rescue Fluent::ConfigError
            raise
        rescue => ex
            @heartbeat_upload_configuration = nil
            @log.error "Configuration exception: #{ex}"
            @log.debug_backtrace
            raise Fluent::ConfigError.new.exception("#{ex.class}: #{ex.message}")
        end

    end

    def start
        @log.debug "starting ..."
        super
        start_heartbeat_upload
    end

    def shutdown
        @log.debug "stopping ..."
        stop_heartbeat_upload
        @log.debug "... stopped"
        super
    end

    def to_s
        @instance_id
    end

private

    LogPrefix = "VMInsights"

    def make_heartbeat_configuration
        config = ::VMInsights::MetricsEngine::Configuration.new OMS::Common.get_hostname, @log, ::VMInsights::DataCollector.new(@log)
        config.poll_interval = @poll_interval
        config
    end

    def start_heartbeat_upload
        @heartbeat_uploader.start(@heartbeat_upload_configuration) { | message |
            begin
                wrapper = {
                    "DataType"  => "INSIGHTS_METRICS_BLOB",
                    "IPName"    => "VMInsights",
                    "DataItems" => message,
                }
                router.emit @tag, Fluent::Engine.now, wrapper
                true
            rescue => ex
                @log.error "Unexpected exception from FluentD Engine: #{ex.message}"
                @log.debug_backtrace
                false
            end
        }
    end

    def stop_heartbeat_upload
        @heartbeat_uploader.stop
    end

    class LogWrapper
        # keep only the required methods
        instance_methods.each { |m|
            undef_method m unless [ :object_id, :__id__, :__send__ ].include?(m)
        }

        def method_missing(method_name, *args, &block)
            # delegate any other method to @logger if it has a public method
            @delegates[method_name].call(*args, &block)
        end

        def initialize(prefix, logger)
            @prefix = prefix + ": "
            @logger = logger
            @delegates = Hash.new { |hash, method_name|
                begin
                    target_method = @logger.public_method method_name
                    hash[method_name] = target_method
                rescue NameError
                    Proc.new { raise NoMethodError, method_name }
                end
            }
        end

        def trace(*args, &block)
            @logger.trace @prefix, *args, &block
        end

        def debug(*args, &block)
            @logger.debug @prefix, *args, &block
        end

        def info(*args, &block)
            @logger.info @prefix, *args, &block
        end

        def warn(*args, &block)
            @logger.warn @prefix, *args, &block
        end

        def error(*args, &block)
            @logger.error @prefix, *args, &block
        end
    end
end # class Fluent::VMInsights
