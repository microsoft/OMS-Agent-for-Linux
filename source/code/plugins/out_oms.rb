class Fluent::OutputOMS < Fluent::Output
  Fluent::Plugin.register_output('out_oms', self)

  Cert_path = '/etc/opt/microsoft/omsagent/certs/oms.crt';
  Key_path =  '/etc/opt/microsoft/omsagent/certs/oms.key';

  # Endpoint URL ex. localhost.local/api/
  config_param :endpoint_url, :string

  # Raise errors that were rescued during HTTP requests?
  config_param :raise_on_error, :bool, :default => true

  def initialize
    super
    require 'net/http'
    require 'net/https'
    require 'uri'
    require 'yajl'
    require 'openssl'
  end

  def configure(conf)
    super
    @uri = URI.parse( @endpoint_url )
  end

  def start
    super
    @verified_certs = false
    test_connection
  end

  def shutdown
    super
  end

  def read_certificate
    return true if @verified_certs
    begin
      raw = File.read Cert_path
      @cert = OpenSSL::X509::Certificate.new raw
      raw = File.read Key_path
      @key  = OpenSSL::PKey::RSA.new raw
    rescue => e
      $log.error "Error reading certs. #{e}"
      return false
    else
      @verified_certs = true
      return true
    end
  end

  def default_http
    http = Net::HTTP.new( @uri.host, @uri.port )
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.cert = @cert
    http.key = @key
    http.open_timeout = 30
    return http
  end

  def test_connection
    return false unless read_certificate

    begin
      # attempt a quick connection to the server.
      http = default_http
      http.start {
          response = http.head('/')
          http.finish
      }
    rescue => e # rescue all StandardErrors
      $log.error "Connection to server not available. #{e}"
      return false
    else
      $log.debug "Connection to server verified."
      return true
    end
  end

  def create_request(tag, time, record)
    url =  @endpoint_url
    uri = URI.parse(url)
    req = Net::HTTP::Post.new(uri.path)
    req.body = Yajl.dump(record)
    return req, uri
  end

  def start_request(req, uri)
    return false unless read_certificate
    res = nil

    begin
      http = default_http
      res = http.start {|http|  http.request(req) }

    rescue => e # rescue all StandardErrors
      # server didn't respond
      $log.warn "Net::HTTP.#{req.method.capitalize} raises exception: #{e.class}, '#{e.message}'"

      raise e if @raise_on_error
      return false
    else
      if res and res.is_a?(Net::HTTPSuccess)
        return true
      end
      if res
        res_summary = "#{res.code} #{res.message} #{res.body}"
      else
        res_summary = "res=nil"
      end
      $log.warn "Failed to #{req.method} #{req.body} #{uri} (#{res_summary})"
      return false
    end # end begin
  end # end start_request

  def handle_record(tag, time, record)
    req, uri = create_request(tag, time, record)
    success = start_request(req, uri)
    if success
      $log.debug "Sent #{tag}"
    end
  end

  def emit(tag, es, chain)
      es.each do |time, record|
        # Ignore empty records
        if record != nil and record.size > 0
          handle_record(tag, time, record)
        end
      end
      chain.next
  end

end
