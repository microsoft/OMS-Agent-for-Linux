module OMS

  class MockLog
    attr_reader :logs

    def initialize
      clear
    end

    def clear
      @logs = []
    end
    
    #Making message optional here because a Fluentd call was throwing ArgumentError
    # $log.trace { "registered #{name} plugin '#{type}'" } (fluentd-0.12.24/lib/fluent/plugin.rb:122)
    def trace(message="")
      @logs << message
    end
    
    def debug(message)
      @logs << message
    end

    def info(message)
      @logs << message
    end

    def warn(message)
      @logs << message
    end
    
    def error(message)
      @logs << message
    end
  end

  class TestHostname
    attr_reader :AddressType
    attr_reader :Hostname
    attr_reader :SpecCompliant

    def initialize(addressTypeArg=:RFC1123Hostname,specComplianceArg,hostNameArg)
      case addressTypeArg
        when :RFC1123Hostname
          @AddressType = addressTypeArg
        when :IPv4
          @AddressType = addressTypeArg
        when :IPv6
          @AddressType = addressTypeArg
        else
          raise TypeError, "#{addressTypeArg} not a valid address type for these tests."
      end

        # NOTE:  As of 2017/10/04 Spec Compliant is presumed to mean the hostname string
        # is any of:
        # 1.  A valid hostname according to RFC 1123, but taking the lower maximum size of 63 until otherwise instructed.
        # 2.  A valid IPv4 address.
        # 3.  A valid IPv6 address.
      if [true, false].include? specComplianceArg
        @SpecCompliant = specComplianceArg
      else
        raise TypeError, "#{specComplianceArg} must be explicitly true or false."
      end

      @Hostname = hostNameArg
    end
  end

end
