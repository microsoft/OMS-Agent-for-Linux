module CollectdModule
  class Collectd
  require_relative 'oms_common'
  require_relative 'omslog'

    def transform(record, hostname)
      if record.to_s == ''
        # nil or empty, return empty record
        return {}
      end
      record["Timestamp"] = OMS::Common.format_time(Time.now.to_f)
      collections = []
      record["dsnames"].each_index {|i|
        counter_pair = {}
        if record["type_instance"].empty?
          counter_pair["CounterName"] = record["dsnames"][i]
        else
          counter_pair["CounterName"] = record["type_instance"] + "." + record["dsnames"][i]
        end
        counter_pair["Value"] = record["values"][i]
        if counter_pair["Value"].nil?
          OMS::Log.warn_once("Dropping null value for counter #{counter_pair['CounterName']}.")
        else
          collections.push(counter_pair) 
        end
      }
      data_items = []
      data_info = {}
      data_info["Timestamp"] = record["Timestamp"]
      data_info["Host"] = hostname
      data_info["ObjectName"] = record["type"]

      plugin = record["plugin_instance"]
      record["InstanceName"] = (plugin ||="").empty? ? "_Total" : plugin
      data_info["InstanceName"] = record["InstanceName"]

      data_info["Collections"] = collections
      data_items.push(data_info)

      return data_items
    end


    #add additional meta such as ObjectName, InstanceName, etc.
    def transform_and_wrap(record, hostname)
      if record.to_s != '' and record["error_class"]=="Fluent::BufferQueueLimitError"
        OMS::Log.warn_once("Buffer Queue limit exceeded, collectD metrics not being sent to OMS")
        return
      end

      if record.to_s != '' and !record.has_key?("dsnames")
        OMS::Log.warn_once("Invalid CollectD metric record found. Discarding data")
        return
      end

      data_items = transform(record, hostname)
      if (data_items != nil and data_items.size > 0)
        wrapper = {
        "DataType"=>"LINUX_PERF_BLOB",
        "IPName"=>"LogManagement",
        "DataItems"=>data_items
      }
        return wrapper
      else
          # no data items, send a empty array that tells ODS
          # output plugin to not the data
        return {}
      end
    end
  end

end


