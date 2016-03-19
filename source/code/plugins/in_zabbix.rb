#!/usr/local/bin/ruby

module Fluent

	class ZabbixInput < Input
		Fluent::Plugin.register_input('zabbix_alerts', self)

		def initialize
			super
			require 'json'
			require 'date'
			require '/opt/microsoft/omsagent/plugin/zabbixapi' 
			require_relative 'zabbix_lib'
			
			@watermark_file = '/var/opt/microsoft/omsagent/state/zabbix_watermark'
			@default_watermark = Time.now.to_i
		end

		config_param :run_interval, :time, :default => nil
		config_param :tag, :string, :default => "oms.zabbix"
		config_param :zabbix_url, :string, :default => "http://localhost/zabbix/api_jsonrpc.php"
		config_param :zabbix_username, :string, :default => "Admin"
		config_param :zabbix_password, :string, :default => "zabbix"
		def configure (conf)
			super
		end

		def get_alerts
			time = Time.now.to_f
			records = @zabbix_lib.get_and_wrap
			# only emit non empty records
			if !records.empty?
				router.emit(@tag, time, records)
			end
		end

		def start
			@zabbix_lib = ZabbixModule::Zabbix.new(ZabbixModule::RuntimeError.new, @watermark_file, @default_watermark, ZabbixApiWrapper, @zabbix_url, @zabbix_username, @zabbix_password)
			if @run_interval
				@finished = false
				@condition = ConditionVariable.new
				@mutex = Mutex.new
				@thread = Thread.new(&method(:run_periodic))
			else
				get_alerts
			end
		end

		def shutdown
			if @run_interval
				@mutex.synchronize {
					@finished = true
					@condition.signal
				}
				@thread.join
			end
		end

		def run_periodic
			@mutex.lock
			done = @finished
			until done
				@condition.wait(@mutex, @run_interval)
				done = @finished
				@mutex.unlock
				if !done
					get_alerts
				end
				@mutex.lock
			end
			@mutex.unlock
		end
	end

end
