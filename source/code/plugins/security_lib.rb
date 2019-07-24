# frozen_string_literal: true

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

    def self.get_ident(ident)
      # To allow a more flexible regex we accept any message containing 'CEF'
      # or '%ASA' as a valid message and converting it into the correct identifier
      return 'CEF' if ident.include?('CEF')
      return '%ASA' if ident.include?('%ASA')
      OMS::Log.warn_once("Failed to find ident: '#{ident}'")
      return nil
    end

    def self.get_data_type(ident)
      return nil if ident.nil?

      return 'SECURITY_CEF_BLOB' if ident.start_with?('CEF')
      return 'SECURITY_CISCO_ASA_BLOB' if ident.start_with?('%ASA')

      OMS::Log.warn_once("Failed to find data type for record with ident: '#{ident}'")
      nil
    end
  end
end
