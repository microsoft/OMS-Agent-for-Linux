module ZabbixModule
	require_relative 'zabbixapi'

	class LoggingBase
		def log_error(text)
		end
	end
	
	class RuntimeError < LoggingBase
		def log_error(text)
			$log.info "ZabbixLib RuntimeError: #{text}"
		end
	end
	
	class Zabbix
		def initialize(error_handler, watermark_time, zabbix_client, zabbix_url, zabbix_username, zabbix_password)
			@error_handler = error_handler
			@watermark_time = watermark_time
			@zabbix_client = zabbix_client
			@zabbix_url = zabbix_url
			@zabbix_username = zabbix_username
			@zabbix_password = zabbix_password
		end
		
		# Retrieves all zabbix alerts in json format 
		# after a certain timestamp	
		#
		def get_alert_records
			begin
				@zbx = @zabbix_client.connect(
				  :url => @zabbix_url,
				  :user => @zabbix_username,
				  :password => @zabbix_password
				)
			rescue => error
				@error_handler.log_error("Unable to connect to Zabbix Server the given time interval error: \n")
				@error_handler.log_error("#{error} \n")
				return {}
			end
		
			begin
				raw_triggers = @zbx.query(
				  :method => "trigger.get",
				  :params => {
					:filter => {
					  :value => "1"
					},
					:output => "extend",
					:expandData => true
				  }
				)
			rescue => error
				@error_handler.log_error("Unable to retrieve alerts for the given time interval error: \n")
				@error_handler.log_error("#{error} \n")
				return {}
			end
			
			triggers = JSON.parse(raw_triggers.to_json)				
			oms_alerts = []
			last_ingest_time = @watermark_time
			
			triggers.each { |trigger| 
				if (trigger["lastchange"].to_i > @watermark_time)
					trigger["description"] = trigger["description"].sub('{HOST.NAME}', trigger["host"])
					oms_alerts.push(trigger)

					# update the latest record ingestion time
					if (trigger["lastchange"].to_i > last_ingest_time)
						last_ingest_time = trigger["lastchange"].to_i
					end
				end
			}
			
			# update watermark_time to be the latest ingestion time
			@watermark_time = last_ingest_time
			
			return oms_alerts
		end
  
		# adds additional meta needed for ODS (i.e. DataType, IPName)
		#
		def get_and_wrap
			data_items = get_alert_records
			if (data_items != nil and data_items.size > 0)
				  wrapper = {
					"DataType"=>"LINUX_ZABBIXALERTS_BLOB",
					"IPName"=>"AlertManagement",
					"DataItems"=>data_items
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