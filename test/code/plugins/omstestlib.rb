module OMS

  class MockLog
    attr_reader :logs

    def initialize
      clear
    end

    def clear
      @logs = []
    end
    
    def debug(message)
      @logs << message
    end
    
    def error(message)
      @logs << message
    end
  end

end
