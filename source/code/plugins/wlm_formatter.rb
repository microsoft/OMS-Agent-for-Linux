require "securerandom"
require 'json'
require 'stringio'
require_relative 'omslog'
require_relative 'oms_common'

module Digest
    # Took sample from https://github.com/rails/rails/blob/a9dc45459abcd9437085f4dd0aa3c9d0e64e062f/activesupport/lib/active_support/core_ext/digest/uuid.rb#L16
    # Generates a v5 non-random UUID (Universally Unique IDentifier).
    #
    # Using Digest::MD5 generates version 3 UUIDs; Digest::SHA1 generates version 5 UUIDs.
    # uuid_from_hash always generates the same UUID for a given name and namespace combination.
    #
    # See RFC 4122 for details of UUID at: http://www.ietf.org/rfc/rfc4122.txt

  def self.uuid_from_hash(name)
    hash = Digest::SHA1.new
    version = 5

    hash.update("WLM_Linux_MP")
    hash.update(name)

    ary = hash.digest.unpack("NnnnnN")
    ary[2] = (ary[2] & 0x0FFF) | (version << 12)
    ary[3] = (ary[3] & 0x3FFF) | 0x8000

    "%08x-%04x-%04x-%04x-%04x%08x" % ary
  end
end

module WLM

  class MPStore 
    class << self
      def Initialize()
        @@class_name_guids = Hash.new
        @@key_properties = Hash.new
        @@properties = Hash.new
        @@cim_properties = Hash.new    
      end

      def get_class_name_guid(className)
        return @@class_name_guids[className]
      end

      def is_key_property(className, propertyName)
        return @@key_properties.has_key?(className + "_" + propertyName)
      end

      def get_property_guid(className,propertyName)
        return @@properties[className + "_" + propertyName]
      end
        
      def get_cim_property(className,propertyName)
        return @@cim_properties[className+"_"+propertyName]
      end

      def load(file_name)
        classes = []
       
        begin
          file = File.read(file_name)
        rescue => e
          $log.error "Unable to read file #{file_name}"
        end # begin
       
        begin
          classes = JSON.parse(file)
        rescue => e
          $log.error "Error parsing file #{file_name} : #{e}"
        end # begin

        classes.each do |workload_class|
          @@class_name_guids[workload_class["Name"]] =  workload_class["Id"]
          workload_class["properties"].each do |prop|
            if !(prop.has_key? "CimName")
              next
            end # if
                            
            if prop["IsKey"]
              @@key_properties[workload_class["Name"]+"_"+prop["Name"]] = prop["Id"]
            end # if
            @@properties[workload_class["Name"]+"_"+prop["Name"]] = prop["Id"]
                            
            if @@cim_properties.has_key? (workload_class["Name"]+"_"+prop["CimName"])
              @@cim_properties[workload_class["Name"]+"_"+prop["CimName"]].push(prop["Name"])
            else
              @@cim_properties[workload_class["Name"]+"_"+prop["CimName"]] = [prop["Name"]]
            end # if
          end # do |prop|               
        end # do |workload_class|
      end # method load
      
    end # class self
  end # class MPStore

  class WLMClassInstance
   
    def initialize(class_name)
      @class_name = class_name      
      @class_id = MPStore.get_class_name_guid(class_name)
      @properties = Hash.new
      @key_properties = Hash.new
    end

    def add_property(property_name, property_value)       
        
      if MPStore.is_key_property(@class_name,property_name)
        @key_properties[MPStore.get_property_guid(@class_name, property_name)] = property_value.to_sym
      end

      @properties[MPStore.get_property_guid(@class_name, property_name)] = property_value.to_sym  
    end # method add_property
    
    def add_cim_property(property_name, property_value)
      MPStore.get_cim_property(@class_name, property_name).each do |prop|
        add_property(prop, property_value)
      end # do
    end # method add_cim_property

    def add_key_property(property_guid, property_value)         
      @key_properties[property_guid] = property_value.to_sym
      @properties[property_guid] = property_value.to_sym
    end # method add_key_property

    def get_class_id
      return @class_id
    end

    def get_key_properties()
      return @key_properties
    end

    def get_all_properties
      return @properties
    end

    def create_sub_class_instance(class_name)
      sub_instance = WLMClassInstance.new(class_name)
      @key_properties.each {|key,value| sub_instance.add_key_property(key,value)}
      return sub_instance
    end # method create_sub_class_instance
    
  end # class WLMClassInstance

  class WLMDiscoveryData
    
    def initialize(rule_name, computer_name)
      @rule_id = Digest.uuid_from_hash(rule_name)
      @root_managed_entity_id = Digest.uuid_from_hash(computer_name)
      @source_health_service_id = Digest.uuid_from_hash(computer_name+"HealthService")
      @instance_array = Array.new
    end

    def create_root_instance(class_name)
      return WLMClassInstance.new(class_name)
    end

    def add_instance(new_instance)
      @instance_array.push(new_instance)
    end 

    def generate_xml(class_name)
      xml_buffer = StringIO.new
      xml_buffer << "<DataItem type=System.DiscoveryData time=#{Time.now.strftime("%Y-%m-%dT%H:%M:%S.%7N%:z")} sourceHealthServiceId="+@source_health_service_id+">"
      xml_buffer << "<DiscoveryType>0</DiscoveryType>"
      xml_buffer << "<DiscoverySourceType>0</DiscoverySourceType>"
      xml_buffer << "<DiscoverySourceObjectId>{"+@rule_id+"}</DiscoverySourceObjectId>"
      xml_buffer << "<DiscoverySourceManagedEntity>{"+@root_managed_entity_id+"}</DiscoverySourceManagedEntity>" 
      xml_buffer << "<ClassInstances>"
      @instance_array.each do  |instance|
        xml_buffer << "<ClassInstance TypeId={"+instance.get_class_id()+"}>"
        xml_buffer << "<Settings>"
        property_map = instance.get_all_properties()            
        property_map.keys.each do |instance_property_key|
          xml_buffer << "<Setting>"
          xml_buffer << "<Name>{"+instance_property_key+"}</Name>"
          xml_buffer << "<Value>"+String(property_map[instance_property_key])+"</Value>"
          xml_buffer << "</Setting>"
        end # do |instance_property_key|
        xml_buffer << "</Settings>"
        xml_buffer << "</ClassInstance>"
      end # do |instance|
      xml_buffer << "</ClassInstances>"
      xml_buffer << "</DataItem>"
      return xml_buffer.string  
    end # method generate_xml
    
  end # class WLMDiscoveryData

  class WLMDataFormatter

    def initialize(wlm_class_file)
      MPStore.Initialize
      MPStore.load(wlm_class_file)
      @parent_key_properties = {}
    end

    def get_discovery_xml(wclass)
      discovery  = WLMDiscoveryData.new(wclass["discovery_id"],OMS::Common.get_fully_qualified_domain_name)
      wclass["discovery_data"].each do |instance|
        wlm_instance = discovery.create_root_instance(wclass["class_name"])
        if wclass.has_key? "parent"
          @parent_key_properties[wclass["parent"]].each do |key, value|
            wlm_instance.add_key_property(key,value)
          end # do |key, value|
        end # if
        instance.each do |properties|
          properties.each do |key,value|
            wlm_instance.add_cim_property(key,value)
          end # do |key,value|
        end # do |properties|
        discovery.add_instance(wlm_instance)
        if wclass["class_name"] == "Universal Linux Computer"
          @parent_key_properties["Universal Linux Computer"] = wlm_instance.get_key_properties
        end # if
      end # do |instance| 
      $log.debug "Discovery xml generated for #{wclass["class_name"]}"
      return discovery.generate_xml(wclass["class_name"])  
    end # method get_discovery_xml
    
  end# class WLMDataFormatter
end # module WLM
