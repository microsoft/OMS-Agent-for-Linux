class OmiOms
  require 'json'
  require_relative 'oms_common'
  require_relative 'omslog'
  
  attr_reader :specific_mapping

  def initialize(object_name, instance_regex, counter_name_regex, omi_mapping_path, omi_interface=nil, common=nil)
    @object_name = object_name
    @counter_name_regex = counter_name_regex
    @instance_regex = instance_regex
    @omi_mapping_path = omi_mapping_path

    @specific_mapping = get_specific_mapping
    if @specific_mapping
      @conf_error = false
      @instance_property = @specific_mapping["InstanceProperty"]
      @cim_to_oms = get_cim_to_oms_mappings(@specific_mapping["CimProperties"])
    else
      @conf_error = true
      return
    end
    
    if common == nil
      common = OMS::Common
    end
    
    @hostname = common.get_hostname or "Unknown host" 

    if omi_interface
      @omi_interface = omi_interface
    else
      require_relative 'Libomi'
      @omi_interface = Libomi::OMIInterface.new
    end
    @omi_interface.connect

  end

  def get_specific_mapping
    begin
      file = File.read(@omi_mapping_path)
    rescue => error
      $log.error "Unable to read file #{@omi_mapping_path}"
      return
    end
    
    begin
      mapping = JSON.parse(file)
    rescue => error
      $log.error "Error parsing file #{@omi_mapping_path} : #{error}"
      return
    end

    specific_mapping = nil

    mapping.each { |class_info| 
      if class_info["ObjectName"] == @object_name
        specific_mapping = class_info
        break
      end
    }

    if specific_mapping == nil
      $log.error "Could not find ObjectName '#{@object_name}' in #{@omi_mapping_path}"
      return
    end
    return specific_mapping
  end

  def get_cim_to_oms_mappings(cimproperties)
    cim_to_oms = {}
    cimproperties.each { |maps|
      cim_name = maps["CimPropertyName"]
      oms_name = maps["CounterName"]
      # Map cim_name to both CounterName and DisplayName
      if maps.has_key?("DisplayName")
        display_counter_name = maps["DisplayName"]
        cim_to_oms[cim_name] = [oms_name, display_counter_name]
      else
        cim_to_oms[cim_name] = oms_name
      end
    }
    return cim_to_oms
  end

  def omi_to_oms_instance(omi_instance, timestamp)
    oms_instance = {}
    oms_instance["Timestamp"] = timestamp
    oms_instance["Host"] = @hostname
    oms_instance["ObjectName"] = @object_name
    # get the specific instance value given the instance property name (i.e. Name, InstanceId, etc. )
    oms_instance["InstanceName"] = omi_instance[@specific_mapping["InstanceProperty"]]
    oms_instance_collections = []
    
    # go through each CimProperties in the specific mapping,
    # if counterName is collected, perform the lookup for the value
    # else skip to the next property
    
    # Filter properties. Watch out! We get them as CIM but the regex is with OMS property names
    omi_instance.each do |property, value|
      # CimProperty may have a DisplayName attribute; if so, use that as the CounterName
      if @cim_to_oms[property].is_a?(Array)
        oms_property_name = @cim_to_oms[property][0]
        oms_property_display_name = @cim_to_oms[property][1]
      else
        oms_property_name = @cim_to_oms[property]
        oms_property_display_name == nil
      end
      begin
        if /#{@counter_name_regex}/.match(oms_property_name)
          if value.nil?
            OMS::Log.warn_once("Dropping null value for counter #{oms_property_name}.")
          else
            counter_pair = {}
            if oms_property_display_name == nil
              counter_pair["CounterName"] = oms_property_name
            else
              counter_pair["CounterName"] = oms_property_display_name
            end
            counter_pair["Value"] = value
            oms_instance_collections.push(counter_pair) 
          end
        end
      rescue RegexpError => e
        @conf_error = true
        $log.error "Regex error on counter_name_regex : #{e}"
        return
      end
    end
    oms_instance["Collections"] = oms_instance_collections
    return oms_instance
  end

  def enumerate(time)
    return nil if @conf_error

    namespace = @specific_mapping["Namespace"]
    cim_class_name = @specific_mapping["CimClassName"]
    items = [[namespace, cim_class_name]]
    record_txt = @omi_interface.enumerate(items)
    instances = JSON.parse record_txt

    # Filter based on instance names
    begin
      instances.select!{ |instance| 
        /#{@instance_regex}/.match(instance[@instance_property])
      }
    rescue RegexpError => e
      @conf_error = true
      $log.error "Regex error on instance_regex : #{e}"
      return
    end
 
    timestamp = OMS::Common.format_time(time)   
    # Convert instances to oms format
    instances.map!{ |instance| 
      omi_to_oms_instance(instance, timestamp)
    }

    if instances.length > 0
      wrapper = {
        "DataType"=>"LINUX_PERF_BLOB",
        "IPName"=>"LogManagement",
        "DataItems"=>instances
      }
      return wrapper
    end
  end

  def disconnect
    @omi_interface.disconnect
  end
end
