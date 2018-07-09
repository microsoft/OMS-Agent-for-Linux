require_relative 'oms_omi_lib'

class WlmOmiOms < OmiOms

  def initialize(object_name, instance_regex, counter_name_regex, omi_mapping_path, omi_interface=nil, common=nil)
    super
    @hostname = OMS::Common.get_fully_qualified_domain_name unless common
  end

  def omi_to_oms_instance(omi_instance, timestamp)
    oms_instance = super
    oms_instance["Host"] = @hostname
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
      omi_to_oms_instance(instance, timestamp)
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
