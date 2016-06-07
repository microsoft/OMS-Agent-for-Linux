require 'rexml/document'
require 'cgi'
require 'digest'
require 'set'

require_relative 'oms_common'

class LinuxUpdates

    @@delimiter = "_"
    @@hostOSDetails = `cat /etc/opt/microsoft/scx/conf/scx-release`.split(/\r?\n/)
    @@hostOSDetailsMap = Hash[(@@hostOSDetails.map {|s| s.split("=")}).map {|key, value| [key, value]}]

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
        instanceXML.elements.each(propertyXPath) { |inst| #AnonFunc in rb.
            name = inst.attributes['NAME']
            rexmlText = REXML::XPath.first(inst, 'VALUE').get_text # TODO escape unicode chars like "&amp;"
            value = rexmlText ? rexmlText.value.strip : ''
            ret[name] = value
        }
        ret
    end

    def self.availableUpdatesXMLtoHash(availableUpdatesXML)
        availableUpdatesHash = instanceXMLtoHash(availableUpdatesXML)
        ret = {}
        
        ret["CollectionName"] = availableUpdatesHash["Name"] + @@delimiter + 
                                availableUpdatesHash["Version"] + @@delimiter + 
                                @@hostOSDetailsMap["OSFullName"]
        ret["PackageName"] = availableUpdatesHash["Name"]
        ret["PackageVersion"] = availableUpdatesHash["Version"]
        ret["Timestamp"] = OMS::Common.format_time(availableUpdatesHash["BuildDate"].to_i)
        ret["Repository"] = availableUpdatesHash.key?("Repository") ? availableUpdatesHash["Repository"] : ""
        ret["Installed"] = false
        ret
    end

    def self.installedPackageXMLtoHash(packageXML)
        packageHash = instanceXMLtoHash(packageXML)
        ret = {}
        
        ret["CollectionName"] = packageHash["Name"] + @@delimiter + 
                                packageHash["Version"] + @@delimiter + 
                                @@hostOSDetailsMap["OSFullName"]
        ret["PackageName"] = packageHash["Name"]
        ret["PackageVersion"] = packageHash["Version"]
        ret["Timestamp"] = OMS::Common.format_time(packageHash["InstalledOn"].to_i)
        ret["Size"] = packageHash["Size"]
        ret["Repository"] = packageHash.key?("Repository") ? packageHash["Repository"] : "" 
        ret["Installed"] = true
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

    def self.isInstalledPackageInstanceXML(instanceXML)
        instanceXML.attributes['CLASSNAME'] == 'MSFT_nxPackageResource'
    end

    def self.isAvailableUpdateInstanceXML(instanceXML)
        instanceXML.attributes['CLASSNAME'] == 'MSFT_nxAvailableUpdatesResource'
    end

    def self.transform_and_wrap(inventoryXMLstr, host, time, force_send_run_interval = 0)

        # Do not send duplicate data if we are not forced to
        hash = Digest::SHA256.hexdigest(inventoryXMLstr)

        if force_send_run_interval > 0 and Time.now - @@force_send_last_upload > force_send_run_interval
            @@log.debug "LinuxUpdates : Force sending inventory data"
            @@force_send_last_upload = Time.now
        elsif hash == @@prev_hash
            @@log.debug "LinuxUpdates : Discarding duplicate inventory data. Hash=#{hash[0..5]}"
            return {}
        end
        @@prev_hash = hash

        # Extract the instances in xml format
        inventoryXML = strToXML(inventoryXMLstr)
        instancesXML = getInstancesXML(inventoryXML)

        # Split installedPackages from services 
        installedPackagesXML = instancesXML.select { |instanceXML| isInstalledPackageInstanceXML(instanceXML) }
        availableUpdatesXML = instancesXML.select { |instanceXML| isAvailableUpdateInstanceXML(instanceXML) }

        # Convert to xml to hash/json representation
        installedPackages = installedPackagesXML.map { |installedPackage|  installedPackageXMLtoHash(installedPackage)}
        availableUpdates = availableUpdatesXML.map { |availableUpdate|  availableUpdatesXMLtoHash(availableUpdate)}

        # Remove duplicate services because duplicate CollectionNames are not supported. TODO implement ordinal solution
        installedPackages = removeDuplicateCollectionNames(installedPackages)
        availableUpdates = removeDuplicateCollectionNames(availableUpdates)       
        
        collections = []
        
        if (installedPackages.size > 0)
            collections += installedPackages
        end
        
        if  (availableUpdates.size > 0)
            collections += availableUpdates
        end

        timestamp = OMS::Common.format_time(time)
        wrapper = {
            "DataType"=>"LINUX_UPDATES_SNAPSHOT_BLOB",
            "IPName"=>"Updates",
            "DataItems"=>[{
                    "Timestamp" => timestamp,
                    "Computer" => host,
                    "OSType" => "Linux",
                    "OSName" => @@hostOSDetailsMap["OSName"],
                    "OSVersion" => @@hostOSDetailsMap["OSVersion"],
                    "OSFullName" => @@hostOSDetailsMap["OSFullName"],
                    "Collections"=> collections
                }]}
          @@log.debug "LinuxUpdates : installedPackages x #{installedPackages.size}, 
                                        availableUpdates x #{availableUpdates.size}"
          return wrapper
    end
end