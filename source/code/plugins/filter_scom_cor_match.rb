require_relative 'scom_common'

module Fluent
  class SCOMCorrelatedMatchFilter < SCOMTimerFilterPlugin
    #Filter plugin that generates an event when first regex matches and 
    #sceond regex matches before given time interval
    Fluent::Plugin.register_filter('filter_scom_cor_match', self)
    
    desc 'stores regex on whose match timer starts'    
    config_param :regexp1, :string, :default => nil
    desc 'stores regex which needs to match after match for regexp1'
    config_param :regexp2, :string, :default => nil
        
    attr_reader :expression1
    attr_reader :key1
    attr_reader :expression2
    attr_reader :key2
    attr_reader :time_interval
    
    def initialize()
      super
    end
    
    def start
      super
    end
    
    def shutdown
      super
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
      result = record
      #Check if a match is found for regexp1
      if !@exp1_found and @expression1.match(record[key1].to_s)
        # Match found, change state to exp1_found and start timer
        set_timer()
        $log.debug "Match found for regex #{@regexp1} ID #{@event_id}. Timer Started."
      end # if
      #Check for regexp2 match if regexp1 was found
      if @exp1_found and @expression2.match(record[key2].to_s)
        # Match found: Change state, stop timer and form SCOM event
        reset_timer()
        result = SCOM::Common.get_scom_record(time, @event_id, @event_desc, record)
        $log.debug "Event found for ID #{@event_id}"
      end # if
      result
    end # method filter
        
  end # class SCOMCorrelatedMatchFilter
end # module Fluent

