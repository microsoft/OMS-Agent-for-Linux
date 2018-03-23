require "rexml/document"
require "cgi"
require 'digest'
require 'json'
require 'date'

require_relative 'changetracking_lib'
require_relative 'oms_common'


class ChangeTrackingRunner 
	CHANGE_TRACKING_FILE = ARGV[0] 
	CHANGE_TRACKING_STATE_FILE = CHANGE_TRACKING_FILE + ".hash"
	CHANGE_TRACKING_INVENTORY_STATE_FILE = CHANGE_TRACKING_FILE + ".inventory.hash"

	def self.transform_and_wrap()
            return ChangeTracking.transform_and_wrap(CHANGE_TRACKING_FILE, CHANGE_TRACKING_STATE_FILE, CHANGE_TRACKING_INVENTORY_STATE_FILE)
        end
end

ret = ChangeTrackingRunner.transform_and_wrap()
puts ret.to_json if !ret.nil?
