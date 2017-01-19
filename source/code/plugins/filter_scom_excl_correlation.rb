module Fluent
  class SCOMExclusiveCorrelationFilter < Filter
    #Filter plugin that generates an event when first regex matches and 
    #sceond regex does not match before given time interval
    Fluent::Plugin.register_filter('filter_scom_excl_correlation', self)
    
    desc 'stores regex on whose match timer starts'    
    config_param :regexp1, :string, :default => nil
    desc 'stores regex which should not match after match for regexp1'
    config_param :regexp2, :string, :default => nil
    desc 'time interval in which regexp2 should not occur'
    config_param :time_interval, :integer, :default => 0
    desc 'event number to be sent to SCOM'
    config_param :event_id, :string, :default => nil
    desc 'event description to be sent to SCOM'
    config_param :event_desc, :string, :default => nil
        
    attr_reader :expression1
    attr_reader :key1
    attr_reader :expression2
    attr_reader :key2
    attr_reader :time_interval
        
    def initialize()
      super
      require_relative 'scom_common'
      @exp1_found = false
      @timer = nil
      @lock = Mutex.new
    end
        
    def configure(conf)
      super
            
      raise ConfigError, "Configuration does not contain 2 expressions" unless @regexp1 and @regexp2
      raise ConfigError, "Configuration does not have corresponding event ID" unless @event_id
      raise ConfigError, "Configuration does not have a time interval" unless @time_interval
      @key1, exp1 = @regexp1.split(/ /,2)
      raise ConfigError, "regexp1 does not contain 2 parameters" unless exp1
      @expression1 = Regexp.compile(exp1)
      @key2, exp2 = @regexp2.split(/ /,2)
      raise ConfigError, "regexp2 does not contain 2 parameters" unless exp2
      @expression2 = Regexp.compile(exp2)
    end
        
    def flip_state()
      @lock.synchronize {
        @exp1_found = !@exp1_found
      }
    end
        
    def filter(tag, time, record)
      #Check if a match is found for regexp1
      if !@exp1_found and @expression1.match(record[key1].to_s)
        # Match found, change state to exp1_found and start timer
        flip_state()
        @timer = Thread.new { sleep @time_interval; timer_expired() }
        $log.debug "Match found for regex #{@regexp1} ID #{@event_id}. Timer Started."
      end # if
      #Check for regexp2 match if regexp1 was found
      if @exp1_found and @expression2.match(record[key2].to_s)
        #Match found: change state and stop timer
        flip_state()
        @timer.terminate()
        @timer = nil
      end # if
      record
    end
        
    def timer_expired()
      flip_state()
      time = Engine.now
      # Match for regexp2 not found within time, form SCOM event
      result = SCOM::Common.get_scom_record(time, @event_id, @event_desc)
      $log.debug "Event found for ID #{@event_id}"
      router.emit("scom.event", time, result)
    end
        
  end # class SCOMExclusiveCorrelationFilter
end # module Fluent



