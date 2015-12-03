module OMS

  class Common
    require 'json'
    require 'net/http'
    require 'net/https'
    require 'time'

    require_relative 'omslog'
    require_relative 'oms_configuration'
    
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
        Time.at(time).utc.iso8601(3) # UTC with milliseconds
      end

      def create_error_tag(tag)
        "ERROR::#{tag}::"
      end

      # create an HTTP object which uses HTTPS
      def create_secure_http(uri)
        http = Net::HTTP.new( uri.host, uri.port )
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.open_timeout = 30
        return http
      end # create_secure_http

      # create an HTTP object to ODS
      def create_ods_http(ods_uri)
        http = create_secure_http(ods_uri)
        http.cert = Configuration.cert
        http.key = Configuration.key
        return http
      end # create_ods_http

      # create an HTTPRequest object to ODS
      # parameters:
      #   path: string. path of the request
      #   record: Hash. body of the request
      # returns:
      #   HTTPRequest. request to ODS
      def create_ods_request(path, record)
        headers = {}
        headers["Content-Type"] = "application/json"

        req = Net::HTTP::Post.new(path, headers)
        # Serialize the record
        msg = JSON.dump(record)
        req.body = msg
        return req
      end # create_ods_request

      # start a request
      # parameters:
      #   req: HTTPRequest. request
      #   secure_http: HTTP. HTTPS
      #   ignore404: bool. ignore the 404 error when it's true
      # returns:
      #   string. body of the response
      def start_request(req, secure_http, ignore404 = false)
        # Tries to send the passed in request
        # Raises a RuntimeException if the request fails.
        # This exception should only be caught by the fluentd engine so that it retries sending this 
        begin
          res = nil
          res = secure_http.start { |http|  http.request(req) }
        rescue => e # rescue all StandardErrors
          # Server didn't respond
          raise "Net::HTTP.#{req.method.capitalize} raises exception: #{e.class}, '#{e.message}'"
        else
          if res and res.is_a?(Net::HTTPSuccess)
            return res.body
          end

          if res
            if ignore404 and res.code == "404"
              return ''
            end

            res_summary = "(#{res.code} #{res.message} #{res.body})"
          else
            res_summary = "(res=nil)"
          end

          raise "Failed to #{req.method} at #{req.to_s} #{res_summary}"  
        end # end begin
      end # end start_request
    end # Class methods

  end # class Common

end # module OMS
