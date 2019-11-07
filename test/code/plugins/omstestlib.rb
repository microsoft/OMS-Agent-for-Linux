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

end
