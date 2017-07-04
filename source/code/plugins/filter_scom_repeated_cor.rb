require_relative 'scom_common'

module Fluent
  class SCOMRepeatedCorrelationFilter < SCOMTimerFilterPlugin
    #Filter plugin that generates event when a regex matches a given 
    #number of time in a given time interval.
    Fluent::Plugin.register_filter('filter_scom_repeated_cor', self)
     
    desc 'regex that needs to match'    
    config_param :regexp1, :string, :default => nil
    desc 'Number of times the  regex should match'
    config_param :num_occurrences, :integer, :default => 0
        
    attr_reader :expression
    attr_reader :key
    attr_reader :time_interval
        
    def initialize()
      super
      @counter = 0
    end
        
    def configure(conf)
      super
            
      raise ConfigError, "Configuration does not contain an expression" unless @regexp1
      raise ConfigError, "Configuration must give a value greater than 0 for num_occurrences" unless (@num_occurrences > 0)
      @key, exp = @regexp1.split(/ /,2)
      raise ConfigError, "regexp1 does not contain 2 parameters" unless exp
      @expression = Regexp.compile(exp)
    end
        
    def reset_counter()
      @lock.synchronize {
        @counter = 0
      }
    end
        
    def filter(tag, time, record)
      result = record
       # Check if a match found for regexp1     
      if !@exp1_found and @expression.match(record[key].to_s)
        # Match found, change state to exp1_found and start timer
        set_timer()
        @counter += 1
        $log.debug "Match found for regex #{@regexp1} ID #{@event_id}. Timer Started."
      elsif @exp1_found and @expression.match(record[key].to_s) 
        @counter += 1
      end # if
      # Check if expected number of occurences reached
      if @counter == @num_occurrences
        # Reset state and counter. Form SCOM event.
        reset_timer()
        reset_counter()
        result = SCOM::Common.get_scom_record(time, @event_id, @event_desc, record)
        $log.debug "Event found for ID #{@event_id}"
      end # if
      result
    end
        
    def timer_expired()
      super
      reset_counter()
    end
        
  end # class SCOMRepeatedCorrelationFilter
end # module Fluent



