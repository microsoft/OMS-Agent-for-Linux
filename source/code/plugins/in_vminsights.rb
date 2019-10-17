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
            @heartbeat_uploader = conf[:MockMetricsEngine] || ::VMInsights::MetricsEngine.new
            @heartbeat_upload_configuration = make_heartbeat_configuration
        rescue Fluent::ConfigError
            raise
        rescue => ex
            @heartbeat_upload_configuration = nil
            @log.error "#{self}: Configuration exception: #{ex}"
            @log.debug_backtrace
            raise Fluent::ConfigError.new.exception("#{ex.class}: #{ex.message}")
        end

    end

    def start
        @log.debug "#{self}: starting ..."
        super
        start_heartbeat_upload
    end

    def shutdown
        @log.debug "#{self}: stopping ..."
        stop_heartbeat_upload
        @log.debug "#{self}: ... stopped"
        super
    end

    def to_s
        @instance_id
    end

private

    def make_heartbeat_configuration
        config = ::VMInsights::MetricsEngine::Configuration.new OMS::Common.get_hostname, @log, ::VMInsights::DataCollector.new
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

end # class Fluent::VMInsights
