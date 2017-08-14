require 'rexml/document'
require 'cgi'
require 'digest'
require 'set'
require 'logger'

require_relative 'oms_common'

class ChangeTracking

    PREV_HASH = "PREV_HASH"
    LAST_UPLOAD_TIME = "LAST_UPLOAD_TIME"

    @@log =  Logger.new(STDERR) #nil
    @@log.formatter = proc do |severity, time, progname, msg|
        "#{severity} #{msg}\n"
    end

    # def self.log= (value)
    #     @@log = value
    # end

    @@force_send_last_upload = Time.now

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

    def self.serviceXMLtoHash(serviceXML)
        serviceHash = instanceXMLtoHash(serviceXML)
        serviceHash["CollectionName"] = serviceHash["Name"]
        serviceHash["InventoryChecksum"] = Digest::SHA256.hexdigest(serviceHash.to_json)
        serviceHash
    end

    def self.packageXMLtoHash(packageXML)
        packageHash = instanceXMLtoHash(packageXML)
        ret = {}
        ret["Architecture"] = packageHash["Architecture"]
        ret["CollectionName"] = packageHash["Name"]
        ret["CurrentVersion"] = packageHash["Version"]
        ret["Name"] = packageHash["Name"]
        ret["Publisher"] = packageHash["Publisher"]
        ret["Size"] = packageHash["Size"]
        ret["Timestamp"] = OMS::Common.format_time(packageHash["InstalledOn"].to_i)
        ret["InventoryChecksum"] = Digest::SHA256.hexdigest(packageHash.to_json)
        ret
    end

    def self.fileInventoryXMLtoHash(fileInventoryXML)
        fileInventoryHash = instanceXMLtoHash(fileInventoryXML)
        ret = {}
        ret["FileSystemPath"] = fileInventoryHash["DestinationPath"]
        ret["CollectionName"] = fileInventoryHash["DestinationPath"]
        ret["Size"] = fileInventoryHash["FileSize"]
        ret["Owner"] = fileInventoryHash["Owner"]
        ret["Group"] = fileInventoryHash["Group"]
        ret["Mode"] = fileInventoryHash["Mode"]
        ret["Contents"] = fileInventoryHash["Contents"]
        ret["DateModified"] = OMS::Common.format_time_str(fileInventoryHash["ModifiedDate"])
        ret["DateCreated"] = OMS::Common.format_time_str(fileInventoryHash["CreatedDate"])
        ret["InventoryChecksum"] = Digest::SHA256.hexdigest(fileInventoryHash.to_json)
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

    def self.transform(inventoryXMLstr, log = nil)
        # Extract the instances in xml format
        inventoryXML = strToXML(inventoryXMLstr)
        instancesXML = getInstancesXML(inventoryXML)

        # Split packages from services 
        packagesXML = instancesXML.select { |instanceXML| isPackageInstanceXML(instanceXML) }
        servicesXML = instancesXML.select { |instanceXML| isServiceInstanceXML(instanceXML) }
        fileInventoriesXML = instancesXML.select { |instanceXML| isFileInventoryInstanceXML(instanceXML) }

        # Convert to xml to hash/json representation
        packages = packagesXML.map { |package|  packageXMLtoHash(package)}
        services = servicesXML.map { |service|  serviceXMLtoHash(service)}
        fileInventories = fileInventoriesXML.map { |fileInventory|  fileInventoryXMLtoHash(fileInventory)}

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
        @@log.debug "The keys in inventory_hash - #{inventory_hash.keys}"        
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
            @@log.warn "Multiple change types found. Incorrect inventory xml generated.\n 
                        The inventory XML should only have one change type, but this XML had -
                        #{inventory_hash.keys}"
            return {} # Returning null.
        else
            return {} # Returning null.
        end
    end

    def self.getHash(file_path)
            ret = {}
            if File.exist?(file_path) # If file exists
                @@log.debug "Found the file {file_path}. Fetching the Hash"
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
                @@log.debug "Could not find the file #{file_path}"
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


    def self.transform_and_wrap(inventoryFile, inventoryHashFile)
        if File.exist?(inventoryFile)                       
            @@log.debug ("Found the change tracking inventory file.")
            # Get the parameters ready.
            time = Time.now
            force_send_run_interval_hours = 24
            force_send_run_interval = force_send_run_interval_hours.to_i * 3600
            @hostname = OMS::Common.get_hostname or "Unknown host"

            # Read the inventory XML.
            file = File.open(inventoryFile, "rb")
            xml_string = file.read; nil # To top the output to show up on STDOUT.

            previousSnapshot = ChangeTracking.getHash(inventoryHashFile)
            previous_inventory_checksum = {}
            begin
                if !previousSnapshot.nil?
                  previous_inventory_checksum = JSON.parse(previousSnapshot[PREV_HASH])
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
                previousSnapshotTime = DateTime.parse(previousSnapshot[LAST_UPLOAD_TIME]).to_time
                if force_send_run_interval > 0 and 
                    Time.now.to_i - previousSnapshotTime.to_i > force_send_run_interval
                    ChangeTracking.setHash(hash, Time.now,inventoryHashFile)
                elsif !changed_checksum.nil? and !changed_checksum.empty?
                    ChangeTracking.setHash(hash, Time.now, inventoryHashFile)
                else
                    return {}
                end
            else # Previous Hash did not exist. Write it
                # and the return the output.
                ChangeTracking.setHash(hash, Time.now, inventoryHashFile)
            end
            return output
        else
            @@log.warn ("The ChangeTracking inventory xml file does not exists")
            return {}
        end 
    end
end
