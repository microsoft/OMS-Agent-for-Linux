require 'rexml/document'
require 'cgi'
require 'digest'
require 'set'
require 'securerandom'

require_relative 'oms_common'
require_relative 'oms_configuration'
require_relative 'omslog'

class LinuxUpdates

    @@prev_hash = ""
    @@delimiter = "_"
    @@force_send_last_upload = Time.now
    @@os_details = nil

    MAJOR_MINOR_VERSION_REGEX = /([^\.]+)\.([^\.]+).*/
    OMS_ADMIN_FILE = "/etc/opt/microsoft/omsagent/conf/omsadmin.conf"
    SCX_RELEASE_FILE = "/etc/opt/microsoft/scx/conf/scx-release"
    SCHEDULE_NAME_VARIABLE = "SCHEDULE_NAME"
    APT_GET_START_DATE_TIME_FORMAT = "%Y-%m-%d %H:%M:%S"

    def initialize(log, updateRunFile)
        @log = log
        @CURRENT_UPDATE_RUN_FILE = updateRunFile
     end

    def getAgentId()
        return OMS::Configuration.agent_id
    end

    def getHostOSDetails()
        if(@@os_details.nil?)    
           if File.exist?(SCX_RELEASE_FILE) # If file exists
            File.open(SCX_RELEASE_FILE, "r") do |f| # Open file
                f.each_line do |line|       # Split each line and
                    line.split(/\r?\n/).reject{ |l|  # reject all those line
                        !l.include? "=" }.map! {|s|    # which do not
                            s.split("=")}.map! {|key, value| # have "="; split
                                @@os_details[key] = value     # by "=" and add to ret.
                        }
                end
            end
            else
                @log.debug "Could not find the file #{SCX_RELEASE_FILE}"
                @@os_details = {}
            end
        end

        return @@os_details
    end

     def getUpdateRunName()
        ret = {}

        if File.exist?(@CURRENT_UPDATE_RUN_FILE) # If file exists
            File.open(@CURRENT_UPDATE_RUN_FILE, "r") do |f| # Open file
                f.each_line do |line|       # Split each line and
                    line.split(/\r?\n/). reject{ |l| 
                        !l.include? "=" }. map! {|s| 
                            s.split("=")}. map! {|key, value| 
                                ret[key] = value
                        }
                    end
                end
        else
            @log.debug "Could not find the file #{CURRENT_UPDATE_RUN_NAME_FILE}"
        end
        return ret[SCHEDULE_NAME_VARIABLE]
    end

    # This temporary fix is for version management for cache lookup.                        
    def getOSShortName(os_short_name = nil, os_version=nil)
        version = ""
        hostOSDetailsMap = getHostOSDetails()

        # match string of the form (1 or more non . chars)- followed by a . - (1 or more non . chars) - followed by anything
        if hostOSDetailsMap.key?("OSShortName")
            osName = (os_short_name.nil?) ? hostOSDetailsMap["OSShortName"].split("_")[0] : os_short_name.split("_")[0]
        else
            osName =  (os_short_name.nil?) ? hostOSDetailsMap["OSFullName"] : os_short_name.split("_")[0]
        end

        if (os_version.nil?)
            @os_major_version = hostOSDetailsMap["OSVersion"][MAJOR_MINOR_VERSION_REGEX, 1] unless hostOSDetailsMap["OSVersion"].nil?
            @os_minor_version = hostOSDetailsMap["OSVersion"][MAJOR_MINOR_VERSION_REGEX, 2] unless hostOSDetailsMap["OSVersion"].nil?
            @default_version = hostOSDetailsMap["OSVersion"]
        else
            @os_major_version = os_version[MAJOR_MINOR_VERSION_REGEX, 1] unless os_version.nil?
            @os_minor_version = os_version[MAJOR_MINOR_VERSION_REGEX, 2] unless os_version.nil?
            @default_version = os_version
        end 
        
        case osName
        when "Ubuntu"
            if @os_major_version == "12" || @os_major_version == "13"
                version = "12.04"
            elsif  @os_major_version == "14" || @os_major_version == "15"
                version = "14.04"
            elsif  @os_major_version == "16" || @os_major_version == "17"
                version = "16.04"
            else
                version = @default_version
            end
        when "CentOS"
            if @os_major_version == "5"
                version = "5.0" 
            elsif  @os_major_version == "6"
                version = "6.0"
            elsif  @os_major_version == "7"
                version = "7.0"
            else
                version = @default_version
            end
        when "RHEL"
            if @os_major_version == "5"
                version = "5.0" 
            elsif  @os_major_version == "6"
                version = "6.0"
            elsif  @os_major_version == "7"
                version = "7.0"
            else
                version = @default_version
            end
        when "SUSE"
            if @os_major_version == "11"
                version = "11.0" 
            elsif  @os_major_version == "12"
                version = "12.0"
            else
                version = @default_version
            end
        else
            version = @default_version
        end

        return osName + @@delimiter + version
    end

    def self.prev_hash= (value)
        @@prev_hash = value
    end

    def isInstalledPackageInstanceXML(instanceXML)
        instanceXML.attributes["CLASSNAME"] == "MSFT_nxPackageResource"
    end

    def isAvailableUpdateInstanceXML(instanceXML)
        instanceXML.attributes["CLASSNAME"] == "MSFT_nxAvailableUpdatesResource"
    end

    def instanceXMLtoHash(instanceXML)
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

    def availableUpdatesXMLtoHash(availableUpdatesXML, os_short_name)
        availableUpdatesHash = instanceXMLtoHash(availableUpdatesXML)
        ret = {}
        ret["CollectionName"] = availableUpdatesHash["Name"] + @@delimiter + 
                                availableUpdatesHash["Version"] + @@delimiter + os_short_name
        ret["PackageName"] = availableUpdatesHash["Name"]
        ret["Architecture"] = availableUpdatesHash.key?("Architecture") ? availableUpdatesHash["Architecture"] : nil
        ret["PackageVersion"] = availableUpdatesHash["Version"]
        ret["Repository"] = availableUpdatesHash.key?("Repository") ? availableUpdatesHash["Repository"] : nil
        ret["Installed"] = false
        ret["UpdateState"] = "Needed"
        if (Integer(availableUpdatesHash["BuildDate"]) rescue false)
            ret["Timestamp"] = OMS::Common.format_time(availableUpdatesHash["BuildDate"].to_i)
        end
        ret
    end

    def installedPackageXMLtoHash(packageXML, os_short_name)
        packageHash = instanceXMLtoHash(packageXML)
        ret = {}
        
        ret["CollectionName"] = packageHash["Name"] + @@delimiter + 
                                packageHash["Version"] + @@delimiter + os_short_name
        ret["PackageName"] = packageHash["Name"]
        ret["Architecture"] = packageHash.key?("Architecture") ? packageHash["Architecture"] : nil
        ret["PackageVersion"] = packageHash["Version"]  
        ret["Size"] = packageHash["Size"]
        ret["Repository"] = packageHash.key?("Repository") ? packageHash["Repository"] : nil
        ret["Installed"] = true
        ret["UpdateState"] = "NotNeeded"
        if (Integer(packageHash["InstalledOn"]) rescue false)
            ret["Timestamp"] = OMS::Common.format_time(packageHash["InstalledOn"].to_i)
        end
        ret
    end

    def strToXML(xml_string)
        xml_unescaped_string = CGI::unescapeHTML(xml_string)
        REXML::Document.new xml_unescaped_string
    end

    # Returns an array of xml instances (all types)
    def getInstancesXML(inventoryXML)
        instances = []
        xpathFilter = "INSTANCE/PROPERTY.ARRAY/VALUE.ARRAY/VALUE/INSTANCE"
        inventoryXML.elements.each(xpathFilter) { |inst| instances << inst }
        instances
    end

    def removeDuplicateCollectionNames(data_items)
        collection_names = Set.new
        data_items.select { |data_item|
            collection_names.add?(data_item["CollectionName"]) && true || false
        }
    end

    def transform_and_wrap(
        inventoryXMLstr, 
        host, 
        time, 
        force_send_run_interval = 86400,
        osNameParam = nil, 
        osFullNameParam = nil,
        osVersionParam = nil, 
        osShortNameParam = nil)

        agentId = getAgentId()
        hostOSDetailsMap = getHostOSDetails()
       
        # Taking the parameters - Helps in mocking, in the case of tests.
        osName =  (osNameParam == nil) ? hostOSDetailsMap["OSName"] : osNameParam
        osVersion = (osVersionParam == nil) ? hostOSDetailsMap["OSVersion"] : osVersionParam
        osFullName = (osFullNameParam == nil) ? hostOSDetailsMap["OSFullName"] : osFullNameParam
        osShortName = getOSShortName(osShortNameParam, osVersion)

        # Do not send duplicate data if we are not forced to
        hash = Digest::SHA256.hexdigest(inventoryXMLstr)
        @log.debug "LinuxUpdates : Sending available updates information data. Hash=#{hash[0..5]}"

        # Extract the instances in xml format
        inventoryXML = strToXML(inventoryXMLstr)
        instancesXML = getInstancesXML(inventoryXML)

        # Split installedPackages from services 
        installedPackagesXML = instancesXML.select { |instanceXML| isInstalledPackageInstanceXML(instanceXML) }
        availableUpdatesXML = instancesXML.select { |instanceXML| isAvailableUpdateInstanceXML(instanceXML) }

        # Convert to xml to hash/json representation
        installedPackages = installedPackagesXML.map! { |installedPackage|  installedPackageXMLtoHash(installedPackage, osShortName)}
        availableUpdates = availableUpdatesXML.map! { |availableUpdate|  availableUpdatesXMLtoHash(availableUpdate, osShortName)}

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
                    "Host" => host,
                    "AgentId" => agentId,
                    "OSType" => "Linux",
                    "OSName" => osName,
                    "OSVersion" => osVersion,
                    "OSFullName" => osFullName,
                    "Collections"=> collections
                }]}
          @log.debug "LinuxUpdates : installedPackages x #{installedPackages.size}, 
                                        availableUpdates x #{availableUpdates.size}"
          return wrapper
    end

    def updateRunProgressJSONtoHash(updateRunJson, host, time)
        # Sample Record
            # "Timestamp": "2016-10-21T04:30:13.2145776Z",
            # "OSType": "Linux",
            # "UpdateId": "8579fbee-d418-43e7-ac67-5fcc0b11cbb7",
            # "UpdateRunName": "LinuxUpdateRun",
            # "UpdateTitle": "Security Update for git-1.0.0.0",
            # "Status": "Succeeded",
            # "Computer": "LinuxXenial",
            # "StartTime": "2016-10-21 04:25:51Z",
            # "EndTime": "2016-10-21 04:30:02Z"

        update_run_name = getUpdateRunName()

        if updateRunJson.key?("Error")
            status = "Failed"
        else
            status = "Succeeded"
        end

        packages_installed = updateRunJson.key?("Install") ? updateRunJson["Install"] : nil
        if !packages_installed.nil?
            list_of_packages_installed = packages_installed.split("),")
            list_of_packages_installed = list_of_packages_installed.map! {|x| x + ")" }
        end

        packages_upgraded = updateRunJson.key?("Upgrade") ? updateRunJson["Upgrade"] : nil
        if !packages_upgraded.nil?
            list_of_packages_upgraded = packages_upgraded.split("),")
            list_of_packages_upgraded = list_of_packages_upgraded.map! {|x| x + ")" }
        end

        update_run = []

        if !list_of_packages_installed.nil?
            for i in list_of_packages_installed;
                ret = {}
                ret["Computer"] = host
                ret["OSType"] = "Linux"
                ret["UpdateRunName"] = update_run_name

                title = i.strip!
                start_time = updateRunJson["Start-Date"].strip!
                end_time = updateRunJson["End-Date"].strip!
                ret["UpdateTitle"] = (title.nil?)?i : title
                ret["UpdateId"] = SecureRandom.uuid
                ret["Status"] = status
                ret["StartTime"] = (start_time.nil?) ? updateRunJson["Start-Date"] : start_time
                ret["EndTime"] = (end_time.nil?) ? updateRunJson["End-Date"] : end_time
                if (Integer(updateRunJson["Start-Date"]) rescue false)
                    ret["TimeStamp"] = OMS::Common.format_time(updateRunJson["Start-Date"].strftime(APT_GET_START_DATE_TIME_FORMAT))
                else
                    ret["TimeStamp"] = OMS::Common.format_time(time)
                end
                update_run << ret
            end
        end

        if !list_of_packages_upgraded.nil?
            for i in list_of_packages_upgraded;
                ret = {}
                
                ret["Computer"] = host
                ret["OSType"] = "Linux"
                ret["UpdateRunName"] = update_run_name
                
                title = i.strip!
                start_time = updateRunJson["Start-Date"].strip!
                end_time = updateRunJson["End-Date"].strip!
                ret["UpdateTitle"] = (title.nil?)?i : title
                ret["UpdateId"] = SecureRandom.uuid
                ret["Status"] = status
                ret["StartTime"] = (start_time.nil?) ? updateRunJson["Start-Date"] : start_time
                ret["EndTime"] = (end_time.nil?) ? updateRunJson["End-Date"] : end_time
                if (Integer(updateRunJson["Start-Date"]) rescue false)
                    ret["TimeStamp"] = OMS::Common.format_time(updateRunJson["Start-Date"].strftime(APT_GET_START_DATE_TIME_FORMAT))
                else
                    ret["TimeStamp"] = OMS::Common.format_time(time)
                end
                update_run << ret
            end
        end
        # FYI This currently does not handle Purge/Remove cases. Eventually, handle all the cases
        # Purge: {"Start-Date"=>"2016-06-28  21:04:57", "Timezone"=>"UTC", "Tag"=>"update_progress", "ProcessedTime"=>"2016-09-29T22:43:25.000Z", "Commandline"=>" apt-get purge python", "Requested-By"=>" varad (1000)", "Purge"=>" python:amd64 (2.7.11-1), python-pkg-resources:amd64 (20.7.0-1), python-all:amd64 (2.7.11-1), python-dev:amd64 (2.7.11-1), python-setuptools:amd64 (20.7.0-1), python-wheel:amd64 (0.29.0-1), python-pip:amd64 (8.1.1-2ubuntu0.1), python-all-dev:amd64 (2.7.11-1)", "End-Date"=>" 2016-06-28  21:05:01"}
        # Remove: {"Start-Date"=>"2016-06-28  21:05:13", "Timezone"=>"UTC", "Tag"=>"update_progress", "ProcessedTime"=>"2016-09-29T22:43:25.000Z", "Commandline"=>" apt autoremove", "Requested-By"=>" varad (1000)", "Remove"=>" python2.7-dev:amd64 (2.7.11-7ubuntu1), libexpat1-dev:amd64 (2.1.0-7ubuntu0.16.04.2), python2.7-minimal:amd64 (2.7.11-7ubuntu1), libpython-all-dev:amd64 (2.7.11-1), libpython2.7:amd64 (2.7.11-7ubuntu1), python2.7:amd64 (2.7.11-7ubuntu1), libpython2.7-dev:amd64 (2.7.11-7ubuntu1), libpython-stdlib:amd64 (2.7.11-1), libpython-dev:amd64 (2.7.11-1), libpython2.7-minimal:amd64 (2.7.11-7ubuntu1), libpython2.7-stdlib:amd64 (2.7.11-7ubuntu1), python-pip-whl:amd64 (8.1.1-2ubuntu0.1), python-minimal:amd64 (2.7.11-1)", "End-Date"=>" 2016-06-28  21:05:20"}
        return update_run
    end

    def populate_package_updated_record(record, status, kbid)
        return ret
    end
    
    def process_update_run(record, tag, host, time)
        processedJson = {}
        processedJson ["Start-Date"] = record['start-date']
        processedJson ["Timezone"] = OMS::Common.get_current_timezone()
        processedJson ["Tag"] = tag
        processedJson ["ProcessedTime"] = OMS::Common.format_time(time)
        processed_string = record["apt-logs"].split("\n")
        processed_string[0] = "Commandline: " + processed_string[0]
        processed_string.each { |x| 
            x2 = x.split(":", 2)
            processedJson [x2[0]] = x2[1]
        }
        if processedJson.key?("Requested-By")
            @log.debug "LinuxUpdatesProgress: Parsing a record of type #{tag}"
            list_of_updates = updateRunProgressJSONtoHash(processedJson , host, time)
            wrapper = {
                "DataType"=>"UPDATES_RUN_PROGRESS_BLOB",
                "IPName"=>"Updates",
                "DataItems"=> list_of_updates
            }
            @log.debug "LinuxRunUpdates updatesDone: #{list_of_updates.size}"
            return wrapper
        else
            @log.debug "LinuxUpdatesProgress: Found an unattended update"
            return {}
        end
    end
end