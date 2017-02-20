module SCOM

  class Configuration
    require 'openssl'
    require 'uri'
        
    require_relative 'oms_configuration'
    require_relative 'omslog'
    require_relative 'oms_common'
        
    @@configuration_loaded = false
    @@scom_conf_path = '/etc/opt/microsoft/omsagent/scom/conf/omsadmin.conf'
    @@cert_path = '/etc/opt/microsoft/omsagent/scom/certs/scom-cert.pem'
    @@key_path =  '/etc/opt/microsoft/omsagent/scom/certs/scom-key.pem'     
  
    @@cert = nil
    @@key = nil
        
    @@scom_endpoint = nil
    @@scom_event_endpoint = nil
    @@scom_perf_endpoint = nil
    
    @@monitoring_id = nil
    @@fqdn = nil    
      
    def self.load_scom_configuration
      return true if @@configuration_loaded
      return false if !OMS::Configuration.test_onboard_file(@@scom_conf_path) or !OMS::Configuration.test_onboard_file(@@cert_path) or !OMS::Configuration.test_onboard_file(@@key_path) 
            
      begin
        scom_endpoint_url = get_value_from_conf("SCOM_ENDPOINT")
        if(!scom_endpoint_url)
          return false
        end
        @@scom_endpoint = URI.parse( scom_endpoint_url )
        @@scom_event_endpoint = @@scom_endpoint.clone
        @@scom_event_endpoint.path = '/OMEDService/events'
        @@scom_perf_endpoint = @@scom_endpoint.clone
        @@scom_perf_endpoint.path = '/OMEDService/perf'
      rescue => e
        OMS::Log.error_once("Error parsing endpoint url. #{e}")
        return false
      end # begin
      
      begin
        @@monitoring_id = get_value_from_conf("MONITORING_ID")
        if(!monitoring_id)
          return false
        end
      rescue => e
        OMS::Log.error_once("Error parsing monitoring id. #{e}")
        return false
      end # begin
             
      begin
        raw = File.read @@cert_path
        @@cert = OpenSSL::X509::Certificate.new raw
        raw = File.read @@key_path
        @@key = OpenSSL::PKey::RSA.new raw
      rescue => e
        OMS::Log.error_once("Failed to read certificate or key from #{@@cert_path} #{@@key_path}")
        return false
      end # begin
       
      @@fqdn = OMS::Common.get_fully_qualified_domain_name
      if(!@@fqdn)
        return false
      end # if
              
      @@configuration_loaded = true
      return true
    end # method load_configuration
    
    def self.get_value_from_conf(key)
      lines = IO.readlines(@@scom_conf_path).select{ |line| line.start_with?(key)}
      if lines.size == 0
        OMS::Log.error_once("Could not find #{key} in #{conf_path}")
        return nil
      elsif lines.size > 1
        OMS::Log.warn_once("Found more than one #{key} setting in #{conf_path}, will use the first one.")
      end
      return lines[0].split("=")[1].strip
    end

    def self.scom_event_endpoint
      @@scom_event_endpoint
    end

    def self.cert
      @@cert
    end

    def self.key
      @@key
    end

    def self.monitoring_id
      @@monitoring_id
    end

    def self.scom_perf_endpoint
      @@scom_perf_endpoint
    end
    
    def self.fqdn
      @@fqdn
    end

  end # class Configuration
end # module SCOM

