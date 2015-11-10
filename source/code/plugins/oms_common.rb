module OMS

  class Common
    require 'time'
    require_relative 'omslog'
    
    @@OSFullName = nil
    @@Hostname = nil

    class << self
      
      def get_os_full_name(conf_path = "/etc/opt/microsoft/scx/conf/scx-release")
        return @@OSFullName if @@OSFullName != nil

        if File.file?(conf_path)
          conf = File.read(conf_path)
          os_full_name = conf[/OSFullName=(.*?)\\n/, 1]
          if os_full_name and os_full_name.size
            @@OSFullName = os_full_name
          end
        end
        return @@OSFullName
      end

      def get_hostname
        return @@Hostname if @@Hostname != nil

        begin
          hostname = Socket.gethostname.split(".")[0]
        rescue => error
          Log.error_once("Unable to get the Host Name: #{error}")
        else
          @@Hostname = hostname
        end
        return @@Hostname
      end

      def format_time(time)
        Time.at(time).utc.iso8601 # UTC with Z at the
      end

      def create_error_tag(tag)
        "ERROR::#{tag}::"
      end

    end # Class methods

    
  end # class Common
end # module OMS
