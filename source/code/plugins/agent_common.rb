# This file extends the OMS::Common class and with
# methods shared by the topology and telemetry scripts.
# It remains separate in order to retain compatibility between
# plugins from DSC modules and those in the shell bundle.

class StrongTypedClass
  def self.strongtyped_accessor(name, type)
    # setter
    self.class_eval("def #{name}=(value);
    if !value.is_a? #{type} and !value.nil?
        raise ArgumentError, \"Invalid data type. #{name} should be type #{type}\"
    end
    @#{name}=value
    end")

    # getter
    self.class_eval("def #{name};@#{name};end")
  end

  def self.strongtyped_arch(name)
    # setter
    self.class_eval("def #{name}=(value);
    if (value != 'x64' && value != 'x86')
        raise ArgumentError, \"Invalid data for ProcessorArchitecture.\"
    end
    @#{name}=value
    end")
  end
end

module OMS

  # Error codes and categories:
  # User configuration/parameters:
  INVALID_OPTION_PROVIDED = 2
  NON_PRIVELEGED_USER_ERROR_CODE = 3
  # System configuration:
  MISSING_CONFIG_FILE = 4
  MISSING_CONFIG = 5
  MISSING_CERTS = 6
  # Service/network-related:
  HTTP_NON_200 = 7
  ERROR_SENDING_HTTP = 8
  ERROR_EXTRACTING_ATTRIBUTES = 9
  MISSING_CERT_UPDATE_ENDPOINT = 10
  # Internal errors:
  ERROR_GENERATING_CERTS = 11
  ERROR_WRITING_TO_FILE = 12

  class Common

    require 'syslog/logger'

    class << self

      # Helper method that returns true if a file exists and is non-empty
      def file_exists_nonempty(file_path)
        return (!file_path.nil? and File.exist?(file_path) and !File.zero?(file_path))
      end

      # Return logger from provided log facility
      def get_logger(log_facility)

        facility = case log_facility
          # Custom log facilities supported by both Ruby and bash logger
          when "auth"     then Syslog::LOG_AUTHPRIV  # LOG_AUTH is deprecated
          when "authpriv" then Syslog::LOG_AUTHPRIV
          when "cron"     then Syslog::LOG_CRON
          when "daemon"   then Syslog::LOG_DAEMON
          when "ftp"      then Syslog::LOG_FTP
          when "kern"     then Syslog::LOG_KERN
          when "lpr"      then Syslog::LOG_LRP
          when "mail"     then Syslog::LOG_MAIL
          when "news"     then Syslog::LOG_NEWS
          when "security" then Syslog::LOG_SECURITY
          when "syslog"   then Syslog::LOG_SYSLOG
          when "user"     then Syslog::LOG_USER
          when "uucp"     then Syslog::LOG_UUCP

          when "local0"   then Syslog::LOG_LOCAL0
          when "local1"   then Syslog::LOG_LOCAL1
          when "local2"   then Syslog::LOG_LOCAL2
          when "local3"   then Syslog::LOG_LOCAL3
          when "local4"   then Syslog::LOG_LOCAL4
          when "local5"   then Syslog::LOG_LOCAL5
          when "local6"   then Syslog::LOG_LOCAL6
          when "local7"   then Syslog::LOG_LOCAL7

          # default logger will be local0
          else Syslog::LOG_LOCAL0
        end

        if !Syslog.opened?
          Syslog::Logger.syslog = Syslog.open("omsagent", Syslog::LOG_PID, facility)
        end
        return Syslog::Logger.new
      end

      # Return a POST request with the specified headers, URI, and body, and an
      #     HTTP to execute that request
      def form_post_request_and_http(headers, uri_string, body, cert, key, proxy)
        uri = URI.parse(uri_string)
        req = Net::HTTP::Post.new(uri.request_uri, headers)
        req.body = body

        http = create_secure_http(uri, OMS::Configuration.get_proxy_config(proxy))
        http.cert = cert
        http.key = key

        return req, http
      end # form_post_request_and_http

    end

  end

end