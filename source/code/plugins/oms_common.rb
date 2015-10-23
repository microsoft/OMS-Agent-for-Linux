module OMS

  class Common
    def get_hostname
      hostname = "Unknown Host"
      begin
        hostname = Socket.gethostname.split(".")[0]
      rescue => error
        $log.error "Unable to get the Host Name: #{error}"
      end
      return hostname
    end
  end

end
