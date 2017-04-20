require 'rexml/document'
require 'cgi'
require 'digest'
require 'set'
require 'logger'

require_relative 'oms_common'

class ChangeTracking

    PREV_HASH = "PREV_HASH"
    LAST_UPLOAD_TIME = "LAST_UPLOAD_TIME"
    @@storageaccount = nil 
    @@storageaccesstoken = nil

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

    def self.initialize(storageaccount, storageaccesstoken)
        @@storageaccount = storageaccount
        @@storageaccesstoken = storageaccesstoken
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
        serviceHash["Inventorychecksum"] = Digest::SHA256.hexdigest(serviceHash.to_json)
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
        ret["Inventorychecksum"] = Digest::SHA256.hexdigest(packageHash.to_json)
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
        ret["Inventorychecksum"] = Digest::SHA256.hexdigest(fileInventoryHash.to_json)
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
        end

        if inventory_hash.has_key?("services")
           inventory = inventory_hash["services"]
        end

        if inventory_hash.has_key?("fileInventories")
           inventory = inventory_hash["fileInventories"]
        end

        inventory.each do |inventory_item| 
           inventoryChecksum[inventory_item["CollectionName"]] = inventory_item["Inventorychecksum"]
           inventory_item.delete("Inventorychecksum")
        end
        return inventoryChecksum
    end

    def self.comparechecksum(previous_inventory, current_inventory)
        inventoryChecksum =  current_inventory.select { |key, value| lookupchecksum(key, value, previous_inventory) }
        return inventoryChecksum 
    end 

    def self.lookupchecksum(key, value, previous_inventory)
        if previous_inventory.has_key?(key)
           if value == previous_inventory[key]
              return false
           end
        end 
        return true 
    end


    def self.filterbychecksum(checksum_filter, inventory_hash)
 
        inventory = {}

        if inventory_hash.has_key?("packages")
           inventory = inventory_hash["packages"]
        end

        if inventory_hash.has_key?("services")
           inventory = inventory_hash["services"]
        end

        if inventory_hash.has_key?("fileInventories")
           inventory = inventory_hash["fileInventories"]
        end

        filteredInventory = inventory.select {|inventory_item| filterchecksum(inventory_item["CollectionName"], checksum_filter)}

        if inventory_hash.has_key?("packages")
           inventory_hash["packages"] = filteredInventory
        end

        if inventory_hash.has_key?("services")
           inventory_hash["services"] = filteredInventory
        end

        if inventory_hash.has_key?("fileInventories")
           filteredInventoryWithBlob = filteredInventory.map {|inventory_item| addbloburi(inventory_item)}
           inventory_hash["fileInventories"] = filteredInventoryWithBlob
        end

        return inventory_hash
    end

    def self.filterchecksum(key, checksum_filter)
        if checksum_filter.has_key?(key)
	   return true
        end
        return false 
    end

    def self.addbloburi(inventory_item)
        if !@@storageaccount.nil? and !@@storageaccesstoken.nil?
           filePath = inventory_item["CollectionName"]
           date = inventory_item["DateModified"]
           fileName = File.basename(filePath) + date 
           blobUrl = "https://" + @@storageaccount + ".blob.core.windows.net/changetrackingblob/" + fileName + "?" + @@storageaccesstoken 
           inventory_item["FileContentBlobLink"] = blobUrl
        end
        return inventory_item
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
                if File.exist?(file_path) # If file exists
                        File.open(file_path, "w") do |f| # Open file
                                f.puts "#{PREV_HASH}=#{prev_hash}"
                                f.puts "#{LAST_UPLOAD_TIME}=#{last_upload_time}"
                        end
                else
                        File.write(file_path, "#{PREV_HASH}=#{prev_hash}\n#{LAST_UPLOAD_TIME}=#{last_upload_time}")
                end
    end
end
