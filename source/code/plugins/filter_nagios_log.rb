# Copyright (c) Microsoft Corporation.  All rights reserved.
module Fluent
	class NagiosLogFilter < Filter
		Plugin.register_filter('filter_nagios_log', self)

		require_relative 'nagios_parser_lib'

		def start
			super
			@nagios_lib = NagiosModule::Nagios.new(NagiosModule::RuntimeError.new)
		end
			
		# each record represents one line from the nagios log
		def filter(tag, time, record)
			return @nagios_lib.parse_alert_record(record["message"])
		end
	end
end