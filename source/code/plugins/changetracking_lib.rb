require 'rexml/document'
require 'cgi'
require 'digest'

require_relative 'oms_common'

class ChangeTracking

    @@prev_hash = ""
    def ChangeTracking::prev_hash= (value)
        @@prev_hash = value
    end

    def self.instanceXMLtoHash(instanceXML)
        # $log.trace "instanceXMLtoHash"
        ret = {}
        propertyXPath = "PROPERTY"
        instanceXML.elements.each(propertyXPath) { |inst| 
            name = inst.attributes['NAME']
            rexmlText = REXML::XPath.first(inst, 'VALUE').get_text
            value = rexmlText ? rexmlText.value : ''
            ret[name] = value
        }
        ret["CollectionName"] = ret["Name"]
        ret
    end

    def self.strToXML(xml_string)
        $log.trace "strToXML"
        xml_unescaped_string = CGI::unescapeHTML(xml_string)
        REXML::Document.new xml_unescaped_string
    end

    # Returns an array of xml instances
    def self.getInstancesXML(inventoryXML)
        $log.trace "getInstancesXML"
        instances = []
        xpathFilter = "INSTANCE/PROPERTY.ARRAY/VALUE.ARRAY/VALUE/INSTANCE"
        inventoryXML.elements.each(xpathFilter) { |inst| instances << inst }
        instances
    end

    def self.transform_and_wrap(inventoryXMLstr, host, time, force_send = false)

        # Do not send duplicate data if we are not forced to
        hash = Digest::SHA256.hexdigest(inventoryXMLstr)
        if hash == @@prev_hash and force_send == false
            return {}
        end
        @@prev_hash = hash

        $log.trace "transform_and_wrap"
        inventoryXML = strToXML(inventoryXMLstr)
        data_items = getInstancesXML(inventoryXML).map { |inst| instanceXMLtoHash(inst) }
        if (data_items != nil and data_items.size > 0)
            wrapper = {
              "DataType"=>"CONFIG_CHANGE_BLOB",
              "IPName"=>"changetracking",
              "DataItems"=>[
                "Timestamp" => OMS::Common.format_time(time),
                "Computer" => host,
                "ConfigChangeType"=> "Daemons",
                "Collections"=> data_items
              ]
            }
            return wrapper
        else
            # no data items, send a empty array that tells ODS
            # output plugin to not the data
            return {}
        end
    end

end