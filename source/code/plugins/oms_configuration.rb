module OMS

  class Configuration
    require 'openssl'
    require 'uri'

    require_relative 'omslog'
    
    @@ConfigurationLoaded = false

    @@Cert = nil
    @@Key = nil

    @@AgentId = nil
    @@ODSEndpoint = nil
    @@GetBlobODSEndpoint = nil
    @@NotifyBlobODSEndpoint = nil
    @@OmsCloudId = nil
    @@AzureResourceId = nil
    @@UUID = nil
 
    class << self
      
      # test the onboard file existence
      def test_onboard_file(file_name)
        if !File.file?(file_name)
          Log.error_once("Could not find #{file_name} Make sure to onboard.")
          return false
        end
      
        if !File.readable?(file_name)
          Log.error_once("Could not read #{file_name} Check that the read permissions are set for the omsagent user")
          return false
        end

        return true
      end

      def get_proxy_config(proxy_conf_path)
        begin
          proxy_config = parse_proxy_config(File.read(proxy_conf_path))
        rescue SystemCallError # Error::ENOENT
          return {}
        end

        if proxy_config.nil?
          Log.error_once("Failed to parse the proxy configuration in '#{proxy_conf_path}'")
          return {}
        end

        return proxy_config
      end

      def parse_proxy_config(proxy_conf_str)
          # Remove the http(s) protocol
          proxy_conf_str = proxy_conf_str.gsub(/^(https?:\/\/)?/, "")

          # Check for unsupported protocol
          if proxy_conf_str[/^[a-z]+:\/\//]
            return nil
          end

          re = /^(?:(?<user>[^:]+):(?<pass>[^@]+)@)?(?<addr>[^:@]+)(?::(?<port>\d+))?$/ 
          matches = re.match(proxy_conf_str)
          if matches.nil? or matches[:addr].nil? 
            return nil
          end
          # Convert nammed matches to a hash
          Hash[ matches.names.map{ |name| name.to_sym}.zip( matches.captures ) ]
      end

      # load the configuration from the configuration file, cert, and key path
      def load_configuration(conf_path, cert_path, key_path)
        return true if @@ConfigurationLoaded
        return false if !test_onboard_file(conf_path) or !test_onboard_file(cert_path) or !test_onboard_file(key_path)

        endpoint_lines = IO.readlines(conf_path).select{ |line| line.start_with?("OMS_ENDPOINT")}
        if endpoint_lines.size == 0
          Log.error_once("Could not find OMS_ENDPOINT setting in #{conf_path}")
          return false
        elsif endpoint_lines.size > 1
          Log.warn_once("Found more than one OMS_ENDPOINT setting in #{conf_path}, will use the first one.")
        end

        begin
          endpoint_url = endpoint_lines[0].split("=")[1].strip
          @@ODSEndpoint = URI.parse( endpoint_url )
          @@GetBlobODSEndpoint = @@ODSEndpoint.clone
          @@GetBlobODSEndpoint.path = '/ContainerService.svc/GetBlobUploadUri'
          @@NotifyBlobODSEndpoint = @@ODSEndpoint.clone
          @@NotifyBlobODSEndpoint.path = '/ContainerService.svc/PostBlobUploadNotification'
        rescue => e
          Log.error_once("Error parsing endpoint url. #{e}")
          return false
        end

        agentid_lines = IO.readlines(conf_path).select{ |line| line.start_with?("AGENT_GUID")}
        if agentid_lines.size == 0
          Log.error_once("Could not find AGENT_GUID setting in #{conf_path}")
          return false
        elsif agentid_lines.size > 1
          Log.warn_once("Found more than one AGENT_GUID setting in #{conf_path}, will use the first one.")
        end

        begin
          @@AgentId = agentid_lines[0].split("=")[1].strip
        rescue => e
          Log.error_once("Error parsing agent id. #{e}")
          return false
        end

        File.open(conf_path).each_line do |line|
          if line =~ /AZURE_RESOURCE_ID/
            @@AzureResourceId = line.sub("AZURE_RESOURCE_ID=","").strip
          end
          if line =~ /OMSCLOUD_ID/
            @@OmsCloudId = line.sub("OMSCLOUD_ID=","").strip
          end
          if line =~ /UUID/
            @@UUID = line.sub("UUID=","").strip
          end
        end

        begin
          raw = File.read cert_path
          @@Cert = OpenSSL::X509::Certificate.new raw
          raw = File.read key_path
          @@Key  = OpenSSL::PKey::RSA.new raw
        rescue => e
          Log.error_once("Error loading certs: #{e}")
          return false
        end

        @@ConfigurationLoaded = true
        return true        
      end # load_configuration

      def cert
        @@Cert
      end # getter cert

      def key
        @@Key
      end # getter key

      def agent_id
        @@AgentId
      end # getter agent_id

      def ods_endpoint
        @@ODSEndpoint
      end # getter ods_endpoint

      def get_blob_ods_endpoint
        @@GetBlobODSEndpoint
      end # getter get_blob_ods_endpoint

      def notify_blob_ods_endpoint
        @@NotifyBlobODSEndpoint
      end # getter notify_blob_ods_endpoint

      def azure_resource_id
        @@AzureResourceId
      end

      def omscloud_id
        @@OmsCloudId
      end

      def uuid
        @@UUID
      end # getter for VM uuid

    end # Class methods
        
  end # class Common
end # module OMS
