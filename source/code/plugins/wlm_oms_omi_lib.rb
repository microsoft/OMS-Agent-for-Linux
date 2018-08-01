require_relative 'oms_omi_lib'

class WlmOmiOms < OmiOms

  def initialize(object_name, instance_regex, counter_name_regex, omi_mapping_path, omi_interface=nil, common=nil)
    super
    @hostname = OMS::Common.get_fully_qualified_domain_name unless common
    @properties_to_normalize = get_normalizable_cim_properties(@specific_mapping["CimProperties"])
  end

  def get_normalizable_cim_properties(cim_properties)
    properties_to_normalize = {}
    cim_properties.each do |maps|
      if(maps.has_key?"NormalizationFactor")
        properties_to_normalize[maps["CimPropertyName"]] = maps["NormalizationFactor"]
      end # if
    end # |maps|
    return properties_to_normalize
  end

  def convert_bool_values(value)
    case value 
    when "true"
      return "1"
    when "false"
      return "0"
    else 
      return nil
    end
  end

  def normalize_value(property,value)
    if @properties_to_normalize.key?(property)
      nf = @properties_to_normalize[property].to_f
      value = value.to_f
      return (value * nf).to_s
    else 
      return nil
    end
  end

  def process_value(property, value)
    processed_value = nil
    # convert bool values to 0 or 1
    processed_value = convert_bool_values(value) if !processed_value

    # normalize the value if Normalization Factor exist for that cim property
    processed_value = normalize_value(property, value) if !processed_value

    #else return the original value passed
    processed_value = value if !processed_value
    return processed_value
  end

  def omi_to_oms_instance(omi_instance, timestamp, wlm_enabled=false, data_type)
    omi_instance.each do |property,value|
      omi_instance[property] = process_value(property,value)
    end
    oms_instance = super(omi_instance,timestamp,wlm_enabled)
    if(data_type == "WLM_LINUX_PERF_DATA_BLOB")
      oms_instance["Host"] = @hostname
    else 
      oms_instance.delete("Host")
      oms_instance["Computer"] = @hostname
    end
    oms_instance[@object_name] = omi_instance[@specific_mapping["InstanceProperty"]]
    return oms_instance
  end

  def enumerate(time, data_type, ip_name)
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
      omi_to_oms_instance(instance, timestamp, data_type)
    }

    if instances.length > 0
      wrapper = {
        "DataType"=>data_type,
        "IPName"=>ip_name,
        "DataItems"=>instances
      }
      return wrapper
    end
  end
end #WlmOmsOmi
