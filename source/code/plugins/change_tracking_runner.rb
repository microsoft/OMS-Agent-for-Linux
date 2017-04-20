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

        @@storageaccount = ARGV[1]
        @@storageaccesstoken = ARGV[2]

	@@log =  Logger.new(STDERR) #nil
	@@log.formatter = proc do |severity, time, progname, msg|
	        "#{severity} #{msg}\n"
	end

	def self.transform_and_wrap()
		if File.exist?(CHANGE_TRACKING_FILE)
			@@log.debug ("Found the change tracking inventory file.")
                        ChangeTracking.initialize(@@storageaccount, @@storageaccesstoken)
			# Get the parameters ready.
			time = Time.now
			force_send_run_interval_hours = 24
			force_send_run_interval = force_send_run_interval_hours.to_i * 3600
			@hostname = OMS::Common.get_hostname or "Unknown host"

			# Read the inventory XML.
			file = File.open(CHANGE_TRACKING_FILE, "rb")
			xml_string = file.read; nil # To top the output to show up on STDOUT.

			previousSnapshot = ChangeTracking.getHash(CHANGE_TRACKING_STATE_FILE)
                        previousInventoryChecksum = {}
                        if !previousSnapshot.nil?
                          previousInventoryChecksum = JSON.parse(previousHash["PREV_HASH"])
                        end
			#Transform the XML to HashMap
			transformed_hash_map = ChangeTracking.transform(xml_string, @@log)
                        currentInventoryChecksum = ChangeTracking.computechecksum(transformed_hash_map)
                        checksum_filter = ChangeTracking.comparechecksum(previousInventoryChecksum, currentInventoryChecksum)
                        filtered_transformed_hash_map = ChangeTracking.filterbychecksum(checksum_filter, transformed_hash_map)

			output = ChangeTracking.wrap(filtered_transformed_hash_map, @hostname, time)
			hash = currentInventoryChecksum.to_json

			# If there is a previous hash
			if !previousSnapshot.nil?
				# If you need to force send
				if force_send_run_interval > 0 and 
					Time.now.to_i - previousSnapshot[LAST_UPLOAD_TIME].to_i > force_send_run_interval
					ChangeTracking.setHash(hash, Time.now,CHANGE_TRACKING_STATE_FILE)
				else
					ChangeTracking.setHash(hash, Time.now, CHANGE_TRACKING_STATE_FILE)
				end
			else # Previous Hash did not exist. Write it
				# and the return the output.
				ChangeTracking.setHash(hash, Time.now, CHANGE_TRACKING_STATE_FILE)
			end
			return output
		else
			@@log.warn ("The ChangeTracking File does not exists. Make sure it is present at the correct")
			return {}
		end 
	end

end

ret = ChangeTrackingRunner.transform_and_wrap()
puts ret.to_json if !ret.nil?
