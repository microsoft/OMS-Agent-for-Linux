# Copyright (c) Microsoft Corporation.  All rights reserved.
module NagiosModule
	class LoggingBase
		def log_error(text)
		end
	end
	
	class RuntimeError < LoggingBase
		def log_error(text)
			$log.info "RuntimeError: #{text}"
		end
	end
	
	class Nagios
		def initialize(error_handler)
			# Instance variables
			@error_handler = error_handler
		end
		
		# This method will take a line and return the parsed record (data item) in json format 
		# it is a nagios host or service alert	
		#
		def parse_alert_record(line)
			if line.to_s == ''
				# nil or empty, return empty record
				return {}
			end

			if !line['HOST ALERT'] && !line['SERVICE ALERT']
				# not an alert record, return
				return {}
			end
			
			# Nagios Alert Array
			# ex. valid line: [1436810470] HOST ALERT: nagios-5;DOWN;SOFT;1;CRITICAL - Host Unreachable (10.185.208.113)
			# ex. valid line: [1436810490] SERVICE ALERT: nagios-2;Current Users;CRITICAL;SOFT;1;CHECK_NRPE: Error - Could not complete SSL handshake.
			nagios_alert_array = line.split(";")
			
			if nagios_alert_array.length != 5 && nagios_alert_array.length != 6
				# alert records must have 5 or 6 sections, return
				@error_handler.log_error("Alert Array Length invalid: should contain 5 or 6 sections")
				return {}
			end
			
			# Timestamp Host Alertname
			alert_host_array = nagios_alert_array[0].split(":")
			
			if alert_host_array.length != 2
				# timestamp and alert host must be in 2 sections, return
				@error_handler.log_error("timestamp and alert host must be in 2 sections")
				return {}
			end
			
			# Unix Time Alertname
			alert_time_array = alert_host_array[0].split(" ", 2)
			
			# convert UnixTime to TimeGenerated
			time_generated = Time.at(alert_time_array[0][1,10].to_i).utc
			
			offset = 0
			if alert_time_array[1].strip == "HOST ALERT"
				#no op
			elsif alert_time_array[1].strip == "SERVICE ALERT"
				#increment offset index
				offset += 1
			else
				# unrecognized alert name
				@error_handler.log_error("unrecognized alert name")
				return {}
			end

			state = nagios_alert_array[1 + offset]
			state_type = nagios_alert_array[2 + offset]
			alert_priority = nagios_alert_array[3 + offset]
			alert_description = nagios_alert_array[4 + offset]

			parsed_record = {}
			parsed_record["Timestamp"] = time_generated.strftime("%FT%T%:z").to_s
			parsed_record["AlertName"] = alert_time_array[1].strip
			parsed_record["HostName"] = alert_host_array[1].strip
			parsed_record["State"] = state
			parsed_record["StateType"] = state_type
			parsed_record["AlertPriority"] = alert_priority.to_i
			parsed_record["AlertDescription"] = alert_description.strip

			return parsed_record
		end
  
		# adds additional meta needed for ODS (i.e. DataType, IPName)
		#
		def parse_and_wrap(line)
			data_item = parse_alert_record(line)
			if (data_item != nil and data_item.size > 0)
				  wrapper = {
					"DataType"=>"LINUX_NAGIOSALERTS_BLOB",
					"IPName"=>"AlertManagement",
					"DataItems"=>[data_item]
				  }
				  return wrapper
			else
				# no data items, send a empty array that tells ODS
				# output plugin to not send the data
				return {}
			end
		end		
  end
end