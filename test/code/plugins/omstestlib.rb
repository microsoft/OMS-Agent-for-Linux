module OMS

  class MockLog
    attr_reader :logs

    def initialize
      clear
    end

    def clear
      @logs = []
    end
    
    def trace(*message, &block)
      message << "" if message.empty? # maintain compatability with previous "fix"
      collect_log(message, block)
    end
    
    def debug(*message, &block)
      collect_log(message, block)
    end

    def info(*message, &block)
      collect_log(message, block)
    end

    def warn(*message, &block)
      collect_log(message, block)
    end
    
    def error(*message, &block)
      collect_log(message, block)
    end

  private

    def collect_log(message, block)
      # TODO conform to the real fluentd logger and process the block
      # message << block.call if block
      @logs << message[0] unless message.empty?
    end
  end

end
