require 'rexml/document'
require 'cgi'
require 'digest'
require 'set'

require_relative 'oms_common'
require_relative 'omslog'

class ChangeTracking

    PREV_HASH = "PREV_HASH"
    LAST_UPLOAD_TIME = "LAST_UPLOAD_TIME"

    @@force_send_last_upload = Time.now
    @@lastInventorySnapshotTime = Time.now

    @@prev_hash = ""
    def self.prev_hash= (value)
        @@prev_hash = value
    end

    def self.instanceXMLtoHash(instanceXML)
        ret = {}
        propertyXPath = "PROPERTY"
        instanceXML.elements.each(propertyXPath) { |inst|
            name = inst.attributes['NAME']
            rexmlText = REXML::XPath.first(inst, 'VALUE').get_text # TODO escape unicode chars like "&amp;"
            value = rexmlText ? rexmlText.value.strip : ''
            ret[name] = value
        }
        ret
    end

    def self.serviceXMLtoHash(serviceXML, isInventorySnapshot = false)
        serviceHash = instanceXMLtoHash(serviceXML)
        serviceHash["CollectionName"] = serviceHash["Name"]
        #InventoryChecksum should be calculated before InventorySnapshot is filled.
        if isInventorySnapshot == false
           serviceHash["InventoryChecksum"] = Digest::SHA256.hexdigest(serviceHash.to_json)
        end
        serviceHash["IsInventorySnapshot"] = isInventorySnapshot
        serviceHash
    end

    def self.packageXMLtoHash(packageXML, isInventorySnapshot = false)
        packageHash = instanceXMLtoHash(packageXML)
        ret = {}
        ret["Architecture"] = packageHash["Architecture"]
        ret["CollectionName"] = packageHash["Name"]
        ret["CurrentVersion"] = packageHash["Version"]
        ret["Name"] = packageHash["Name"]
        ret["Publisher"] = packageHash["Publisher"]
        ret["Size"] = packageHash["Size"]
        ret["Timestamp"] = OMS::Common.format_time(packageHash["InstalledOn"].to_i)
        #InventoryChecksum should be calculated before InventorySnapshot is filled.
        if isInventorySnapshot == false
           ret["InventoryChecksum"] = Digest::SHA256.hexdigest(packageHash.to_json)
        end
        ret["IsInventorySnapshot"] = isInventorySnapshot

        ret
    end

    def self.fileInventoryXMLtoHash(fileInventoryXML, isInventorySnapshot = false)
        fileInventoryHash = instanceXMLtoHash(fileInventoryXML)
        ret = {}
        ret["FileContentChecksum"] = fileInventoryHash["Checksum"]
        ret["FileSystemPath"] = fileInventoryHash["DestinationPath"]
        ret["CollectionName"] = fileInventoryHash["DestinationPath"]
        ret["Size"] = fileInventoryHash["FileSize"]
        ret["Owner"] = fileInventoryHash["Owner"]
        ret["Group"] = fileInventoryHash["Group"]
        ret["Mode"] = fileInventoryHash["Mode"]
        ret["Contents"] = fileInventoryHash["Contents"]
        ret["DateModified"] = OMS::Common.format_time_str(fileInventoryHash["ModifiedDate"])
        ret["DateCreated"] = OMS::Common.format_time_str(fileInventoryHash["CreatedDate"])

        #InventoryChecksum should be calculated before InventorySnapshot is filled.
        if isInventorySnapshot == false
           ret["InventoryChecksum"] = Digest::SHA256.hexdigest(fileInventoryHash.to_json)
        end
        ret["IsInventorySnapshot"] = isInventorySnapshot
        ret
    end

    def self.strToXML(xml_string)
        xml_unescaped_string = CGI::unescapeHTML(xml_string)
        REXML::Document.new xml_unescaped_string
    end

    # Returns an array of xml instances (all types)
    def self.getInstancesXML(inventoryXML)
        instances = []
        xpathFilter = "INSTANCE/PROPERTY.ARRAY/VALUE.ARRAY/VALUE/INSTANCE"
        inventoryXML.elements.each(xpathFilter) { |inst| instances << inst }
        instances
    end

    def self.removeDuplicateCollectionNames(data_items)
        collection_names = Set.new
        data_items.select { |data_item|
            collection_names.add?(data_item["CollectionName"]) && true || false
        }
    end

    def self.isPackageInstanceXML(instanceXML)
        instanceXML.attributes['CLASSNAME'] == 'MSFT_nxPackageResource'
    end

    def self.isServiceInstanceXML(instanceXML)
        instanceXML.attributes['CLASSNAME'] == 'MSFT_nxServiceResource'
    end

    def self.isFileInventoryInstanceXML(instanceXML)
        instanceXML.attributes['CLASSNAME'] == 'MSFT_nxFileInventoryResource'
    end

    def self.transform(inventoryXMLstr, isInventorySnapshot = false)
        # Extract the instances in xml format
        inventoryXML = strToXML(inventoryXMLstr)
        instancesXML = getInstancesXML(inventoryXML)

        # Split packages from services
        packagesXML = instancesXML.select { |instanceXML| isPackageInstanceXML(instanceXML) }
        servicesXML = instancesXML.select { |instanceXML| isServiceInstanceXML(instanceXML) }
        fileInventoriesXML = instancesXML.select { |instanceXML| isFileInventoryInstanceXML(instanceXML) }

        # Convert to xml to hash/json representation
        packages = packagesXML.map { |package|  packageXMLtoHash(package, isInventorySnapshot)}
        services = servicesXML.map { |service|  serviceXMLtoHash(service, isInventorySnapshot)}
        fileInventories = fileInventoriesXML.map { |fileInventory|  fileInventoryXMLtoHash(fileInventory, isInventorySnapshot)}

        # Remove duplicate services because duplicate CollectionNames are not supported. TODO implement ordinal solution
        packages = removeDuplicateCollectionNames(packages)
        services = removeDuplicateCollectionNames(services)
        fileInventories = removeDuplicateCollectionNames(fileInventories)

        ret = {}
        if packages.size > 0
            ret["packages"] = packages
        end
        if services.size > 0
            ret["services"] = services
        end
        if fileInventories.size > 0
            ret["fileInventories"] = fileInventories
        end

        return ret
    end

    def self.computechecksum(inventory_hash)
        inventory = {}
        inventoryChecksum = {}

        if inventory_hash.has_key?("packages")
           inventory = inventory_hash["packages"]
        elsif inventory_hash.has_key?("services")
           inventory = inventory_hash["services"]
        elsif inventory_hash.has_key?("fileInventories")
           inventory = inventory_hash["fileInventories"]
        end

        inventory.each do |inventory_item|
           inventoryChecksum[inventory_item["CollectionName"]] = inventory_item["InventoryChecksum"]
           inventory_item.delete("InventoryChecksum")
        end
        return inventoryChecksum
    end

    def self.comparechecksum(previous_inventory, current_inventory)
        inventoryChecksumInstalled = {}
        if !current_inventory.nil?
         inventoryChecksumInstalled = current_inventory.select { |key, value| lookupchecksum(key, value, previous_inventory) }
        end

        inventoryChecksumRemoved = {}
        if !previous_inventory.nil?
        inventoryChecksumRemoved = previous_inventory.select { |key, value| lookupchecksum(key, value, current_inventory) }
        end
        return inventoryChecksumRemoved.merge!(inventoryChecksumInstalled)
    end

    def self.lookupchecksum(key, value, previous_inventory)
        if !previous_inventory.nil? and previous_inventory.has_key?(key)
           if value == previous_inventory[key]
              return false
           end
        end
        return true
    end

    def self.markchangedinventory(checksum_filter, inventory_hash)
        inventory = {}
        if inventory_hash.has_key?("fileInventories")
           inventory = inventory_hash["fileInventories"]
           inventory.each {|inventory_item| markchanged(inventory_item["CollectionName"], checksum_filter, inventory_item)}
           filteredInventory = inventory
           inventory_hash["fileInventories"] = filteredInventory
        end
        return inventory_hash
    end

    def self.filterchecksum(key, checksum_filter)
        if checksum_filter.has_key?(key)
        	return true
        end
        return false
    end

    def self.markchanged(key, checksum_filter, inventory_item)
        if checksum_filter.has_key?(key)
           inventory_item["FileContentBlobLink"] = " "
        end
    end

    def self.wrap (inventory_hash, host, time)
        timestamp = OMS::Common.format_time(time)
        wrapper = {
                    "DataType"=>"CONFIG_CHANGE_BLOB",
                    "IPName"=>"changetracking",
                    "DataItems"=>[]
                }

        # Add entries to DataItems array only if they exist.
        if inventory_hash.has_key?("packages")
            wrapper["DataItems"] << {
                            "Timestamp" => timestamp,
                            "Computer" => host,
                            "ConfigChangeType"=> "Software.Packages",
                            "Collections"=> inventory_hash["packages"]
                        }
        end

        if inventory_hash.has_key?("services")
            wrapper["DataItems"] << {
                            "Timestamp" => timestamp,
                            "Computer" => host,
                            "ConfigChangeType"=> "Daemons",
                            "Collections"=> inventory_hash["services"]
                        }
        end

        if inventory_hash.has_key?("fileInventories")
            wrapper["DataItems"] << {
                            "Timestamp" => timestamp,
                            "Computer" => host,
                            "ConfigChangeType"=> "Files",
                            "Collections"=> inventory_hash["fileInventories"]
                        }
        end

        # Returning the default wrapper. This can be nil as well (nothing in the
        # DatatItems array)
        if wrapper["DataItems"].size == 1
            return wrapper
        elsif wrapper["DataItems"].size > 1
            return {} # Returning null.
        else
            return {} # Returning null.
        end
    end

    def self.getHash(file_path)
            ret = {}
            if File.exist?(file_path) # If file exists
                File.open(file_path, "r") do |f| # Open file
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
                return nil
            end
    end

    def self.setHash(prev_hash, last_upload_time, file_path)
                # File.write('/path/to/file', 'Some glorious content')
                File.open(file_path, "w+", 0644) do |f| # Open file
                     f.puts "#{PREV_HASH}=#{prev_hash}"
                     f.puts "#{LAST_UPLOAD_TIME}=#{last_upload_time}"
                end
    end

    def self.setInventoryTimestamp(timestamp, file_path)
        File.open(file_path, "w+", 0644) do |f|
             f.puts "#{timestamp}"
        end
    end

    def self.getInventoryTimestampInRubyTime(file_path)
        time = Time.now - (10 * 60 * 60) # default time to return if file not found or read error
        if File.exist?(file_path)
           content = File.open(file_path, &:gets)
           if !content.nil? and !content.empty?
              time = DateTime.parse(content).to_time
           end
        end
        return time
    end

    def self.transform_and_wrap(inventoryFile, inventoryHashFile, inventoryTimestampFile)
        if File.exist?(inventoryFile)
            # Get the parameters ready.
            time = Time.now
            force_send_run_interval_hours = 10
            force_send_run_interval = force_send_run_interval_hours.to_i * 3600
            @hostname = OMS::Common.get_hostname or "Unknown host"

            # Read the inventory XML.
            file = File.open(inventoryFile, "rb")
            xml_string = file.read; nil # To top the output to show up on STDOUT.
            # ########### INVENTORY #####################
            # if its time to send inventory
            # send the inventory snapshot and dont update any hashes, so change tracking sends a snapshot subsequently
            isInventorySnapshot = false
            @@lastInventorySnapshotTime = getInventoryTimestampInRubyTime(inventoryTimestampFile)
            if Time.now.to_i - @@lastInventorySnapshotTime.to_i >= force_send_run_interval
               isInventorySnapshot = true
            end

            transformed_hash_map = ChangeTracking.transform(xml_string, isInventorySnapshot)

            if isInventorySnapshot
               output = ChangeTracking.wrap(transformed_hash_map, @hostname, time)
               setInventoryTimestamp(Time.now, inventoryTimestampFile)
               return output
            end
            ############ END INVENTORY ##############

            previousSnapshot = ChangeTracking.getHash(inventoryHashFile)
            previous_inventory_checksum = {}
            begin
                if !previousSnapshot.nil?
                  previous_inventory_checksum = JSON.parse(previousSnapshot[PREV_HASH])
                end
            rescue
                previousSnapshot = nil
            end

            current_inventory_checksum = ChangeTracking.computechecksum(transformed_hash_map)
            changed_checksum = ChangeTracking.comparechecksum(previous_inventory_checksum, current_inventory_checksum)
            transformed_hash_map_with_changes_marked = ChangeTracking.markchangedinventory(changed_checksum, transformed_hash_map)

            output = ChangeTracking.wrap(transformed_hash_map_with_changes_marked, @hostname, time)
            hash = current_inventory_checksum.to_json

            # Send inventory irrespectve of changes
            if !changed_checksum.nil? and !changed_checksum.empty?
               ChangeTracking.setHash(hash, Time.now, inventoryHashFile)
               return output
            else
               return {}
            end
        else
            return {}
        end
    end
end
