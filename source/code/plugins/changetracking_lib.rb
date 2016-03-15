require "rexml/document"
require "cgi"

require_relative 'oms_common'

module ChangeTracking

    def self.getInstanceXMLproperty(instanceXML, property)
        search = "//PROPERTY[@NAME='#{property}']" 
        propertyNode = REXML::XPath.first(instanceXML, search)
        # puts search, property, propertyNode#, value
        rexmlText = propertyNode.get_text('VALUE')
        if rexmlText
            return rexmlText.value
        else
            return ''
        end    
    end

    def self.instanceXMLtoHash(instanceXML)
        ret = {}
        
        ret['Name'] = getInstanceXMLproperty(instanceXML, 'Name')
        ret['CollectionName'] = ret['Name']
        ret['Description'] = getInstanceXMLproperty(instanceXML, 'Description')
        ret['State'] = getInstanceXMLproperty(instanceXML, 'State').capitalize
        ret['Path'] = getInstanceXMLproperty(instanceXML, 'Path')
        ret['Runlevels'] = getInstanceXMLproperty(instanceXML, 'Runlevels')
        ret['Enabled'] = getInstanceXMLproperty(instanceXML, 'Enabled')
        ret['Controller'] = getInstanceXMLproperty(instanceXML, 'Controller')

        ret
    end

    def self.strToXML(xml_string)
        xml_unescaped_string = CGI::unescapeHTML(xml_string)
        REXML::Document.new xml_unescaped_string
    end

    # Returns an array of xml instances
    def self.getInstancesXML(inventoryXML)
        instances = []
        xpathFilter = "INSTANCE/PROPERTY.ARRAY/VALUE.ARRAY/VALUE/INSTANCE"
        inventoryXML.elements.each(xpathFilter) { |inst| instances << inst }
        instances
    end

    def self.transform_and_wrap(inventoryXMLstr, host, time)
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