module OMS
  class Diag

    # Defaults for diagnostic
    DEFAULT_IPNAME = "Diagnostics"
    DEFAULT_TAG    = "diag.oms"

    # Mandatory property keys
    DI_KEY_LOGMESSAGE = 'LogData'
    DI_KEY_IPNAME     = 'IPName'
    DI_KEY_TYPE       = 'type'
    DI_KEY_TIME       = 'time'
    DI_KEY_AGENTGUID  = 'sourceHealthServiceId'

    # Constants for dataitem values
    DI_TYPE_XML   = 'System.PropertyBagData'
    DI_TYPE_JSON  = 'JsonData'

    # Record keys
    RECORD_DATAITEMS  = 'DataItems'
    RECORD_IPNAME     = 'IPName'
    RECORD_MGID       = 'ManagementGroupId'

    # Record constant values
    RECORD_MGID_VALUE = '{00000000-0000-0000-0000-000000000002}'

    # Diagnostic logging support minimum version
    DIAG_MIN_VERSION = "1.3.4-127"

    class << self

      @@DiagSupported = nil
      @@InstallInfoPath = "/etc/opt/microsoft/omsagent/sysconf/installinfo.txt"

      # Method to check if diagnostic logging is supported
      #
      # Description:
      # This would tell if current omsagent version supports
      # diagnostic logging
      #
      # NOTE: If this returns false then logs will be rejected silently
      def IsDiagSupported()
        return @@DiagSupported unless @@DiagSupported.nil?

        begin
          # Read installinfo.txt
          versionline = IO.readlines(@@InstallInfoPath)[0]

          # Extract version number
          versionnum = versionline.split()[0]

          # Extract major and minor parts of version number
          cur_major, cur_minor, cur_patch, cur_build = GetVersionParts(versionnum)

          # Check validity of major and minor parts
          if cur_major.nil? or
              cur_minor.nil? or
              cur_patch.nil? or
              cur_build.nil?
            @@DiagSupported = false
            return @@DiagSupported
          end

          # Compare version number
          tar_major, tar_minor, tar_patch, tar_build = GetVersionParts(DIAG_MIN_VERSION)

          # Compare major parts
          if @@DiagSupported.nil?
            if cur_major.to_i > tar_major.to_i
              @@DiagSupported = true
            elsif cur_major.to_i < tar_major.to_i
              @@DiagSupported = false
            end
          end

          # Compare minor parts
          if @@DiagSupported.nil?
            if cur_minor.to_i > tar_minor.to_i
              @@DiagSupported = true
            elsif cur_minor.to_i < tar_minor.to_i
              @@DiagSupported = false
            end
          end

          # Compare patch parts
          if @@DiagSupported.nil?
            if cur_patch.to_i > tar_patch.to_i
              @@DiagSupported = true
            elsif cur_patch.to_i < tar_patch.to_i
              @@DiagSupported = false
            end
          end

          # Compare build parts
          if @@DiagSupported.nil?
            if cur_build.to_i > tar_build.to_i
              @@DiagSupported = true
            elsif cur_build.to_i < tar_build.to_i
              @@DiagSupported = false
            end
          end

        rescue
          return false
        end

        # The version is DIAG_MIN_VERSION
        @@DiagSupported = true if @@DiagSupported.nil?
        return @@DiagSupported
      end

      # Method to be used by INPUT and FILTER plugins for logging

      # Description:
      # This is to be utilized for logging to the diagnostic
      # channel.
      #
      # Parameters:
      # @logMessage[mandatory]: The log message string to be logged
      # @tag[optional]: The tag with which to emit the diagnostic log. The
      # default value would be DEFAULT_TAG
      # @ipname[optional]: IPName can be optionally provided to depict a
      # customized one other than the DEFAULT_IPNAME in diagnostic event
      # @properties[optional]: Hash corresponding to key value pairs that
      # would be added as part of this data item.
      #
      # NOTE: Certain mandatory properties to the dataitem are added by default
      def LogDiag(logMessage, tag=DEFAULT_TAG, ipname=DEFAULT_IPNAME, properties=nil)
        return unless IsDiagSupported()

        # Process default values for tag and ipname if they are passed as nil
        tag ||= DEFAULT_TAG
        ipname ||= DEFAULT_IPNAME

        dataitem = Hash.new

        # Adding parameterized properties
        dataitem.merge!(properties) if properties.is_a?(Hash)

        # Adding mandatory properties
        dataitem[DI_KEY_LOGMESSAGE] = logMessage
        dataitem[DI_KEY_IPNAME]     = ipname
        dataitem[DI_KEY_TIME]       = GetCurrentFormattedTimeForDiagLogs()

        # Following are expected to be taken care of further processing of dataitem
        # by out_oms_diag
        # 1. Removal of DI_KEY_IPNAME key value pair from dataitem
        # 2. Addition of DI_KEY_AGENTGUID key value pair to dataitem
        # 3. Addition of DI_KEY_TYPE key value pair to dataitem

        # Emitting the record
        Fluent::Engine.emit(tag, Fluent::Engine.now, dataitem)
      end

      # Methods for OUTPUT Plugin (out_oms_diag)

      # Description:
      # This is utilized by out_oms_diag for altering certain properties
      # to the dataitems before serialization. This method will be
      # called after aggregating dataitems by IPName and before calling
      # serializer.
      #
      # Parameters:
      # @dataitems[mandatory]: Array of dataitems sent via LogDiag from
      # Input and Filter plugins
      # @agentId[mandatory]: The omsagent guid parsed from OMS configuration
      def ProcessDataItemsPostAggregation(dataitems, agentId)
        # Remove all invalid dataitems
        dataitems.delete_if{|x| !IsValidDataItem?(x)}
        for x in dataitems
          x.delete(DI_KEY_IPNAME)
          x[DI_KEY_AGENTGUID] = agentId
          x[DI_KEY_TYPE] = DI_TYPE_JSON
        end
      end

      # Description:
      # This is used to create diagnostic record set that is serialized
      # and sent to ODS over HTTPS.
      #
      # Parameters:
      # @dataitems[mandatory]: Array of dataitems that are valid
      # @ipname[mandatory]: The ipname for the record
      # @optionalAttributes[optional]: Key value pairs to be added to
      # the record
      def CreateDiagRecord(dataitems, ipname, optionalAttributes=nil)
        record = Hash.new
        record.merge!(optionalAttributes) if optionalAttributes.is_a?(Hash)
        record[RECORD_DATAITEMS] = dataitems
        record[RECORD_IPNAME] = ipname
        record[RECORD_MGID] = RECORD_MGID_VALUE
        record
      end

      # Method used to check if dataitem is valid
      def IsValidDataItem?(dataitem)
        if !dataitem.is_a?(Hash) or
           !dataitem.key?(DI_KEY_LOGMESSAGE) or
           !dataitem[DI_KEY_LOGMESSAGE].is_a?(String) or
           !dataitem.key?(DI_KEY_IPNAME) or
           !dataitem[DI_KEY_IPNAME].is_a?(String) or
           !dataitem.key?(DI_KEY_TIME) or
           !dataitem[DI_KEY_TIME].is_a?(String)
          return false
        end
        true
      end

      # Method used to get current time as per format of diagnostic logs
      def GetCurrentFormattedTimeForDiagLogs()
          Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%6NZ")
      end

      # Method used to get major minor version parts as array of omsagent version
      def GetVersionParts(versionStr)
          version_vals = versionStr.split('-')
          major, minor, patch = version_vals[0].split('.')
          build = version_vals[1]
          return major, minor, patch, build
      end

    end # class << self
  end # class Diag
end # module OMS
