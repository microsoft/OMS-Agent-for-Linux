module OMS

  class Common
    require 'json'
    require 'net/http'
    require 'net/https'
    require 'time'
    require 'zlib'

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
      def create_secure_http(uri, proxy={})
        if proxy.empty?
          http = Net::HTTP.new( uri.host, uri.port )
        else
          http = Net::HTTP.new( uri.host, uri.port,
                                proxy[:addr], proxy[:port], proxy[:user], proxy[:pass])
        end
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.open_timeout = 30
        return http
      end # create_secure_http

      # create an HTTP object to ODS
      def create_ods_http(ods_uri, proxy={})
        http = create_secure_http(ods_uri, proxy)
        http.cert = Configuration.cert
        http.key = Configuration.key
        return http
      end # create_ods_http

      # create an HTTPRequest object to ODS
      # parameters:
      #   path: string. path of the request
      #   record: Hash. body of the request
      #   compress: bool. Whether the body of the request should be compressed
      # returns:
      #   HTTPRequest. request to ODS
      def create_ods_request(path, record, compress)
        headers = {}
        headers["Content-Type"] = "application/json"
        if compress == true
          headers["Content-Encoding"] = "deflate"
        end

        req = Net::HTTP::Post.new(path, headers)
        json_msg = parse_json_record_encoding(record)
        if json_msg.nil?
          return nil
        else
          if compress == true
            req.body = Zlib::Deflate.deflate(json_msg)
          else
            req.body = json_msg
          end
        end
        return req
      end # create_ods_request

      # parses the json record with appropriate encoding
      # parameters:
      #   record: Hash. body of the request
      # returns:
      #   json represention of object, 
      # nil if encoding cannot be applied 
      def parse_json_record_encoding(record)
        msg = nil
        begin
          msg = JSON.dump(record)
        rescue => error 
          # failed encoding, encode to utf-8, iso-8859-1 and try again
          begin
            if !record["DataItems"].nil?
              record["DataItems"].each do |item|
                item["Message"] = item["Message"].encode('utf-8', 'iso-8859-1')
              end
            end
            msg = JSON.dump(record)
          rescue => error
            # at this point we've given up up, we don't recognize
            # the encode, so return nil and log_warning for the 
            # record
            Log.warn_once("Skipping due to failed encoding for #{record}: #{error}")
          end
        end
        return msg
      end

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

  class IPcache
    
    def initialize(refresh_interval_seconds)
      @cache = {}
      @cache_lock = Mutex.new
      @refresh_interval_seconds = refresh_interval_seconds
      @condition = ConditionVariable.new
      @thread = Thread.new(&method(:refresh_cache))
    end

    def get_ip(hostname)
      @cache_lock.synchronize {
        if @cache.has_key?(hostname)
          return @cache[hostname]
        else
          ip = get_ip_from_socket(hostname)
          @cache[hostname] = ip
          return ip
        end
      }
    end

    private
    
    def get_ip_from_socket(hostname)
      begin
        addrinfos = Socket::getaddrinfo(hostname, "echo", Socket::AF_UNSPEC)
      rescue => e
        return nil
      end

      if addrinfos.size >= 1
        return addrinfos[0][3]
      end

      return nil
    end

    def refresh_cache
      while true
        @cache_lock.synchronize {
          @condition.wait(@cache_lock, @refresh_interval_seconds)
          # Flush the cache completely to prevent it from growing indefinitly
          @cache = {}
        }
      end
    end

  end

end # module OMS
