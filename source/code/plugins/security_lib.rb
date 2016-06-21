module OMS
  class Security
    require_relative 'omslog'

    @@LOG_TYPE_MAPPING = {
      '%ASA' => 'SECURITY_CISCO_ASA_BLOB',
      'CEF' => 'SECURITY_CEF_BLOB'
    }

    def self.log_type_mapping
      @@LOG_TYPE_MAPPING
    end

    def self.get_data_type(ident)
      return nil if ident.nil?

      @@LOG_TYPE_MAPPING.each do |key, data_type|
        return data_type if ident.start_with?(key)
      end

      OMS::Log.warn_once("Failed to find data type for record with ident: '#{ident}'")
      nil
    end
  end
end
