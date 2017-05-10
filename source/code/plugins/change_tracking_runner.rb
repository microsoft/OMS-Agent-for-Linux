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

			previousSnapshot = ChangeTracking.getHash(CHANGE_TRACKING_STATE_FILE)
                        previous_inventory_checksum = {}
                        begin
                          if !previousSnapshot.nil?
                            previous_inventory_checksum = JSON.parse(previousSnapshot["PREV_HASH"])
                          end
                        rescue 
			@@log.warn ("Error parsing previous hash file")
                             previousSnapshot = nil
                        end
			#Transform the XML to HashMap
			transformed_hash_map = ChangeTracking.transform(xml_string, @@log)
                        current_inventory_checksum = ChangeTracking.computechecksum(transformed_hash_map)
                        changed_checksum = ChangeTracking.comparechecksum(previous_inventory_checksum, current_inventory_checksum)
                        transformed_hash_map_with_changes_marked = ChangeTracking.markchangedinventory(changed_checksum, transformed_hash_map)

			output = ChangeTracking.wrap(transformed_hash_map_with_changes_marked, @hostname, time)
			hash = current_inventory_checksum.to_json

			# If there is a previous hash
			if !previousSnapshot.nil?
				# If you need to force send
				if force_send_run_interval > 0 and 
					Time.now.to_i - previousSnapshot[LAST_UPLOAD_TIME].to_i > force_send_run_interval
					ChangeTracking.setHash(hash, Time.now,CHANGE_TRACKING_STATE_FILE)
				elsif !changed_checksum.nil? and !changed_checksum.empty?
					ChangeTracking.setHash(hash, Time.now, CHANGE_TRACKING_STATE_FILE)
				else
					return {}
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
