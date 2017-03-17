require "rexml/document"
require "cgi"
require 'logger'
require 'digest'
require 'json'

require_relative 'changetracking_lib'
require_relative 'oms_common'


class ChangeTrackingRunner 
	CHANGE_TRACKING_FILE = ARGV[0] 
	CHANGE_TRACKING_STATE_FILE = CHANGE_TRACKING_FILE + ".hash"
	PREV_HASH = "PREV_HASH"
	LAST_UPLOAD_TIME = "LAST_UPLOAD_TIME"

	@@log =  Logger.new(STDERR) #nil
	@@log.formatter = proc do |severity, time, progname, msg|
	        "#{severity} #{msg}\n"
	end

	def self.transform_and_wrap()
		if File.exist?(CHANGE_TRACKING_FILE)
			@@log.debug ("Found the change tracking inventory file.")

			# Get the parameters ready.
			time = Time.now
			force_send_run_interval_hours = 24
			force_send_run_interval = force_send_run_interval_hours.to_i * 3600
			@hostname = OMS::Common.get_hostname or "Unknown host"

			# Read the inventory XML.
			file = File.open(CHANGE_TRACKING_FILE, "rb")
			xml_string = file.read; nil # To top the output to show up on STDOUT.

			#Transform the XML to HashMap
			transformed_hash_map = ChangeTracking.transform(xml_string, @@log)
                        checksum_hash_map = ChangeTracking.computechecksum(transformed_hash_map)
			output = ChangeTracking.wrap(transformed_hash_map, @hostname, time)
			hash = checksum_hash_map.to_json

			previousSnapshot = getHash()

			# If there is a previous hash
			if !previousSnapshot.nil?
				# If you need to force send
				if force_send_run_interval > 0 and 
					Time.now.to_i - previousSnapshot[LAST_UPLOAD_TIME].to_i > force_send_run_interval
					setHash(hash, Time.now)
				# If the content changed.
				elsif hash != previousSnapshot[PREV_HASH]
					setHash(hash, Time.now)
				else
					return {}
				end
			else # Previous Hash did not exist. Write it
				# and the return the output.
				setHash(hash, Time.now)
			end
			return output
		else
			@@log.warn ("The ChangeTracking File does not exists. Make sure it is present at the correct")
			return {}
		end 
	end

	def self.getHash()
		ret = {}
		if File.exist?(CHANGE_TRACKING_STATE_FILE) # If file exists
			@@log.debug "Found the file {CHANGE_TRACKING_STATE_FILE}. Fetching the Hash"
	        File.open(CHANGE_TRACKING_STATE_FILE, "r") do |f| # Open file
	        	f.each_line do |line|
	            	line.split(/\r?\n/).reject{ |l|  
	                	!l.include? "=" }.map { |s|  
	                    	s.split("=")}.map { |key, value| 
	                    		ret[key] = value 
	                    	}
	        	end
			end
	        return ret
	    else
	    	@@log.debug "Could not find the file #{CHANGE_TRACKING_STATE_FILE}"
	        return nil
	    end
	end

	def self.setHash(prev_hash, last_upload_time)
		# File.write('/path/to/file', 'Some glorious content')
		if File.exist?(CHANGE_TRACKING_STATE_FILE) # If file exists
			File.open(CHANGE_TRACKING_STATE_FILE, "w") do |f| # Open file
				f.puts "#{PREV_HASH}=#{prev_hash}"
				f.puts "#{LAST_UPLOAD_TIME}=#{last_upload_time}"
			end
		else
			File.write(CHANGE_TRACKING_STATE_FILE, "#{PREV_HASH}=#{prev_hash}\n#{LAST_UPLOAD_TIME}=#{last_upload_time}")
		end
	end
end

ret = ChangeTrackingRunner.transform_and_wrap()
puts ret.to_json if !ret.nil?
