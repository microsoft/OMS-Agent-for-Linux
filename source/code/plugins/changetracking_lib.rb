require 'rexml/document'
require 'cgi'
require 'digest'
require 'set'

require_relative 'oms_common'

class ChangeTracking

    @@log = nil
    def self.log= (value)
        @@log = value
    end

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

    def self.transform_and_wrap(inventoryXMLstr, host, time, force_send_run_interval = 0)

        # Do not send duplicate data if we are not forced to
        hash = Digest::SHA256.hexdigest(inventoryXMLstr)

        if force_send_run_interval > 0 and Time.now - @@force_send_last_upload > force_send_run_interval
            @@log.debug "Changetracking : Force sending inventory data"
            @@force_send_last_upload = Time.now
        elsif hash == @@prev_hash
            @@log.debug "ChangeTracking : Discarding duplicate inventory data. Hash=#{hash[0..5]}"
            return {}
        end
        @@prev_hash = hash

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

        if (packages.size > 0 or services.size > 0 or fileInventories.size > 0)
            timestamp = OMS::Common.format_time(time)
            wrapper = {
              "DataType"=>"CONFIG_CHANGE_BLOB",
              "IPName"=>"changetracking",
              "DataItems"=>[
                {
                    "Timestamp" => timestamp,
                    "Computer" => host,
                    "ConfigChangeType"=> "Software.Packages",
                    "Collections"=> packages
                },
                {
                    "Timestamp" => timestamp,
                    "Computer" => host,
                    "ConfigChangeType"=> "Daemons",
                    "Collections"=> services
                },
                {
                    "Timestamp" => timestamp,
                    "Computer" => host,
                    "ConfigChangeType"=> "Files",
                    "Collections"=> fileInventories
                }
              ]
            }
            @@log.debug "ChangeTracking : Packages x #{packages.size}, Services x #{services.size}, Files x #{fileInventories.size}"
            return wrapper
        else
            # no data items, send a empty array that tells ODS
            # output plugin to not the data
            return {}
        end
    end

end
