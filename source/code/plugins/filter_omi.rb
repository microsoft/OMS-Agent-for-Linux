module Fluent
	require 'socket'
	require_relative 'omi_lib'
	
	class OmiFilter < Filter
		Plugin.register_filter('filter_omi', self)
		
		# perf_counters is a string of csv list of performance counters 
		# each item in the list is the Object Name concentated with the Counter Name
		config_param :perf_counters, :string, :default => ""
		
    	# This method is called before starting.
    	def configure(conf)
      		super
			@hostname = "Unknown Host"
			begin
				@hostname = Socket.gethostname
			rescue => error
				$log.error "Unable to get the Host Name"
			end
			@performance_counters = perf_counters
    	end
		
		def start
			super
			@omi_lib = OmiModule::Omi.new(OmiModule::RuntimeError.new, "/etc/opt/microsoft/omsagent/sysconf/omi_mapping.json")
		end
			
		# each record represents one line from the nagios log
		def filter(tag, time, record)
			return @omi_lib.transform_and_wrap(record.to_json, @performance_counters, @hostname, time)
		end
	end
end