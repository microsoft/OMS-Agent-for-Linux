module OmiModule
  class LoggingBase
    def log_error(text)
    end
  end
  
  class RuntimeError < LoggingBase
    def log_error(text)
      $log.error "OmiLibRuntimeError: #{text}"
    end
  end

  class Omi
    require 'json'
    require_relative 'oms_common'
    require_relative 'omslog'
    
    def initialize(error_handler, mapping_file_location)
      # Instance variables
      @error_handler = error_handler

      begin
        file = File.read(mapping_file_location)
      rescue => error
        @error_handler.log_error("Unable to read Mapping file")
        return {}
      end
      
      begin
        @counter_mapping = JSON.parse(file)
      rescue => error
        @error_handler.log_error("Invalid Mapping file format")
        return {}
      end
    end
    
    # returns the dictionary hash of the specified class name,
    # empty if not found
    # 
    def lookup_class_name(class_name, mappings)
      mappings.each { |mapping|
        if mapping["CimClassName"] == class_name
          return mapping
        end
      }
      # log exception class name not found in mappings
      @error_handler.log_error("Class name not found in mappings")
      return {}       
    end     

    # returns data items properly formatted to ODS
    #
    def transform(records, collected_counters, host, time)
      if records.to_s == ''
        # nil or empty, return empty record
        return {}
      end
      
      begin
        records_hash = JSON.parse(records)
      rescue
        @error_handler.log_error("Invalid Input Class Instances format")
        return {}
      end
      
      data_items = []

      records_hash.each { |record|
        # get the specific class mapping
        specific_mapping = lookup_class_name(record["ClassName"], @counter_mapping)
        if (specific_mapping == {})
          # class name not found in map, return empty transformed record
          return {}
        end
        
        transformed_record = {}
        transformed_record["Timestamp"] = OMS::Common.format_time(time)
        transformed_record["Host"] = host
        transformed_record["ObjectName"] = specific_mapping["ObjectName"]
        # get the specific instance value given the instance property name (i.e. Name, InstanceId, etc. )
        transformed_record["InstanceName"] = record[specific_mapping["InstanceProperty"]]
        transformed_record_collections = []
        
        # go through each CimProperties in the specific mapping,
        # if counterName is collected, perform the lookup for the value
        # else skip to the next property
        specific_mapping["CimProperties"].each { |property| 
          if collected_counters.include?("#{transformed_record["ObjectName"]} #{property["CounterName"]}")
            counter_pair = {}
            counter_pair["CounterName"] = property["CounterName"]
            counter_pair["Value"] = record[property["CimPropertyName"]]
            if counter_pair["Value"].nil?
              OMS::Log.warn_once("Dropping null value for counter #{counter_pair['CounterName']}.")
            else
              transformed_record_collections.push(counter_pair) 
            end
          end
        }
        transformed_record["Collections"] = transformed_record_collections
        
        # Data_items example record: [{"Timestamp":"2015-10-01T23:26:23Z","Host":"buntu14","ObjectName":"Processor","InstanceName":"0","Collections":[{"CounterName":"% Processor Time","Value":"0"}]}]
        data_items.push(transformed_record)
      }
      
      return data_items
    end
    
    # adds additional meta needed for ODS (i.e. DataType, IPName)
    #
    def transform_and_wrap(records, collected_counters, host, time)
      data_items = transform(records, collected_counters, host, time)
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
