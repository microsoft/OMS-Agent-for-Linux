require_relative 'scom_common'

module Fluent
  class SCOMExclusiveCorrelationFilter < SCOMTimerFilterPlugin
    #Filter plugin that generates an event when first regex matches and 
    #sceond regex does not match before given time interval
    Fluent::Plugin.register_filter('filter_scom_excl_correlation', self)
    
    desc 'stores regex on whose match timer starts'    
    config_param :regexp1, :string, :default => nil
    desc 'stores regex which should not match after match for regexp1'
    config_param :regexp2, :string, :default => nil
        
    attr_reader :expression1
    attr_reader :key1
    attr_reader :expression2
    attr_reader :key2
    attr_reader :time_interval
        
    def initialize()
      super
      @event_record = nil;
    end
        
    def configure(conf)
      super
            
      raise ConfigError, "Configuration does not contain 2 expressions" unless @regexp1 and @regexp2
      @key1, exp1 = @regexp1.split(/ /,2)
      raise ConfigError, "regexp1 does not contain 2 parameters" unless exp1
      @expression1 = Regexp.compile(exp1)
      @key2, exp2 = @regexp2.split(/ /,2)
      raise ConfigError, "regexp2 does not contain 2 parameters" unless exp2
      @expression2 = Regexp.compile(exp2)
    end
        
    def filter(tag, time, record)
      #Check if a match is found for regexp1
      if !@exp1_found and @expression1.match(record[key1].to_s)
        # Match found, change state to exp1_found and start timer
        set_timer()
        @event_record = record;
        $log.debug "Match found for regex #{@regexp1} ID #{@event_id}. Timer Started."
      end # if
      #Check for regexp2 match if regexp1 was found
      if @exp1_found and @expression2.match(record[key2].to_s)
        #Match found: change state and stop timer
        reset_timer()
        @event_record = nil;
      end # if
      record
    end
        
    def timer_expired()
      super
      time = Engine.now
      # Match for regexp2 not found within time, form SCOM event
      result = SCOM::Common.get_scom_record(time, @event_id, @event_desc, @event_record)
      @event_record = nil;
      $log.debug "Event found for ID #{@event_id}"
      router.emit("scom.event", time, result)
    end
        
  end # class SCOMExclusiveCorrelationFilter
end # module Fluent



