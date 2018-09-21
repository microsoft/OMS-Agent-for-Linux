class BlockLock
    @lock = Mutex.new
    class << self
      Mutex.instance_methods(false).each do |method|
        define_method(method) do |&block|
          @lock.send(method, &block)
        end
      end
    end
  end
