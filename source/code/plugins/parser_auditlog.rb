require 'fluent/parser'

module Fluent
  class AuditLogParser < Parser
    # Register this parser as "time_key_value"
    Plugin.register_parser("parser_auditlog", self)

    def initialize
      super
      require_relative 'auditlog_lib'
    end

    # This method is called after config_params have read configuration parameters
    def configure(conf)
      super
      @parser = AuditLogModule::AuditLogParser.new(AuditLogModule::RuntimeError.new)
    end

    def parse(text)
      time, record = @parser.parse(text)
      yield time, record
    end
  end
end

