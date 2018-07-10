module Fluent

  class WLMOMIDiscovery < Input
    Plugin.register_input('wlm_discovery', self)

    def initialize
      super
      require 'base64'
      require 'open-uri'
      require 'json'
      require_relative 'oms_omi_lib'
      require_relative 'wlm_omi_discovery_lib'
      require_relative 'wlm_formatter'
      require_relative 'oms_common'
    end

    config_param :wlm_class_file, :string
    config_param :discovery_time_file, :string
    config_param :omi_mapping_path, :string

    def configure (conf)
      super
      @default_timeout = 14400
      @metadata_api_version = '2017-08-01'
    end

    def start
      @finished = false
      @condition = ConditionVariable.new
      @mutex = Mutex.new
      @thread = Thread.new(&method(:run_periodic))
    end

    def shutdown
      if @interval
        @mutex.synchronize {
          @finished = true
          @condition.signal
        }
        @thread.join
      end
    end

    def discover
      omi_lib = WLM::WLMOMIDiscoveryCollector.new(@omi_mapping_path)
      discovery_data = omi_lib.get_discovery_data()
      wlm_formatter = WLM::WLMDataFormatter.new(@wlm_class_file)
      discovery_data.each do |wclass|
	if wclass["class_name"].to_s == "Universal Linux Computer"
          wclass["discovery_data"][0]["CSName"] = OMS::Common.get_fully_qualified_domain_name
	end
        discovery_xml = wlm_formatter.get_discovery_xml(wclass)
        instance = {}
        instance["Host"] = OMS::Common.get_fully_qualified_domain_name
        instance["OSType"] = "Linux"
        instance["ObjectName"] = wclass["class_name"]
        instance["EncodedDataItem"] = Base64.strict_encode64(discovery_xml)
        wrapper = {
          "DataType"=>"WLM_LINUX_INSTANCE_DATA_BLOB",
          "IPName"=>"InfrastructureInsights",
          "DataItems"=>[instance]
        }
        router.emit("oms.wlm.discovery", Time.now.to_f, wrapper)
      end # each
      update_discovery_time(Time.now.to_i)
      $log.debug "Discovery data for #{@omi_mapping_path} generated successfully"
      get_vm_metadata()
    end # method discover

    def run_periodic
      begin
        timeout_value = @default_timeout
        last_discovery_time = Time.at(get_last_discovery_time.to_i)
        if(last_discovery_time.to_i > 0)
          next_discovery_time = last_discovery_time + @default_timeout
          current_time = Time.now
          if(current_time >= next_discovery_time)
            discover
          else
            timeout_value = next_discovery_time - current_time
          end # if
        else
          discover
        end # if
        @mutex.lock
        done = @finished
        until done
          $log.debug "#{timeout_value} seconds befor next discovery"
          @condition.wait(@mutex, timeout_value)
          timeout_value = @default_timeout
          done = @finished
          @mutex.unlock
          if !done
            discover
          end
          @mutex.lock
        end # until
        @mutex.unlock
        rescue => e
          $log.error "Error generating discovery data #{e}"
        end # begin
    end # method run_periodic
    
    def update_discovery_time(time)
      begin
        time_file = File.open(@discovery_time_file, "w")
        time_file.write(time.to_s)
      rescue => e
        $log.debug "Error updating last discovery time #{e}"
      ensure
        time_file.close unless time_file.nil?
      end # begin
    end # method update_discovery_time
    
    def get_last_discovery_time()
      begin
        last_discovery_time = File.open(@discovery_time_file, &:readline)
        return last_discovery_time.strip()
      rescue => e
        $log.debug "Error reading last discovery time #{e}"
        return ""
      end # begin
    end # method get_last_discovery_time

    def get_vm_metadata()
      begin
        url_metadata="http://169.254.169.254/metadata/instance?api-version=#{@metadata_api_version}"
        metadata_json = open(url_metadata,"Metadata"=>"true").read
        metadata_instance = { 
          "EncodedVMMetadata" => Base64.strict_encode64(metadata_json),
          "ApiVersion" => @metadata_api_version
        }
        wrapper = {
          "DataType"=>"WLM_LINUX_VM_METADATA_BLOB",
          "IPName"=>"InfrastructureInsights",
          "DataItems"=>[metadata_instance]
        }
        router.emit("oms.wlm.vm.metadata", Time.now.to_f, wrapper)
      rescue => e
        $log.error "Error sending VM metadata #{e}"
      end # begin
    end # method get_vm_metadata

  end # class WLMOMIDiscovery

end # module Fluent
