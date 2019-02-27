module WLM
  class WLMOMIDiscoveryCollector
    require 'json'
    require_relative 'oms_common'
    require_relative 'omslog'
    
    def initialize(omi_mapping_path, omi_interface=nil)
      begin
        file = File.read(omi_mapping_path)
      rescue => e
        @conf_error = true
        $log.error "Unable to read file #{omi_mapping_path}"
      end

      begin
        @omi_mapping = JSON.parse(file)
      rescue => e
        @conf_error = true
        $log.error "Error parsing file #{omi_mapping_path} : #{e}"
      end

      if omi_interface
        @omi_interface = omi_interface
      else
        require_relative 'Libomi'
        @omi_interface = Libomi::OMIInterface.new
      end
      @omi_interface.connect
      @conf_error = false
    end
    
    def enumerate(specific_mapping)
      return nil if @conf_error

      namespace = specific_mapping["Namespace"]
      cim_class_name = specific_mapping["CimClassName"]
      items = [[namespace, cim_class_name]]
      record_txt = @omi_interface.enumerate(items)
      instances = JSON.parse record_txt

      # Filter based on instance names
      begin
        instances.select!{ |instance| 
          /#{specific_mapping["InstanceRegex"]}/.match(instance[specific_mapping["InstanceProperty"]])
        }
      rescue => e
        $log.error "Regex error on instance_regex : #{e}"
        return nil
      end # begin
      return instances
    end # method enumerate
    
    def get_cim_data(instances,specific_mapping)
      cim_data = []
      instances.each do |instance|
        cim_data.push(get_cim_values(instance,specific_mapping))
      end # each
      return cim_data
    end # method get_cim_data
    
    def get_cim_values(instance,specific_mapping)
      cim_values = {}
      cim_properties = specific_mapping["CimProperties"]
      instance.each do |property,value|
       if cim_properties.include? property
         cim_values[property] = value
       end # if
      end # each
      return cim_values
    end # method get_cim_values
    
    def get_specific_discovery(specific_mapping)
      discovery_data = {}
      discovery_data["discovery_id"] = specific_mapping["DiscoveryID"]
      discovery_data["class_name"] = specific_mapping["ClassName"]
      discovery_data["parent"] = specific_mapping["Parent"] if specific_mapping.has_key? "Parent"
      instances = enumerate(specific_mapping)
      discovery_data["discovery_data"] = get_cim_data(instances,specific_mapping)
      return discovery_data
    end # method get_discovery_data

    def get_discovery_data
      discovery_collection = []
      @omi_mapping.each do |specific_mapping|
        discovery_collection.push(get_specific_discovery(specific_mapping))
      end # each
      @omi_interface.disconnect
      return discovery_collection
    end # method get_discovery data

  end # class WLMOMIDiscoveryCollector
end # module WLM
