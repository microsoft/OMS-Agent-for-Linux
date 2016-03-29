module OMS

  class MockLog
    attr_reader :logs

    def initialize
      clear
    end

    def clear
      @logs = []
    end

    def trace(message)
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
