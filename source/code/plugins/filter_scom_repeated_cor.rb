module Fluent
  class SCOMRepeatedCorrelationFilter < Filter
    #Filter plugin that generates event when a regex matches a given 
    #number of time in a given time interval.
    Fluent::Plugin.register_filter('filter_scom_repeated_cor', self)
     
    desc 'regex that needs to match'    
    config_param :regexp1, :string, :default => nil
    desc 'Number of times the  regex should match'
    config_param :num_occurrences, :integer, :default => 0
    desc 'time interval in which the match should occur'
    config_param :time_interval, :integer, :default => 0
    desc 'event number to be sent to SCOM'
    config_param :event_id, :string, :default => nil
    desc 'event description to be sent to SCOM'
    config_param :event_desc, :string, :default => nil
        
    attr_reader :expression
    attr_reader :key
    attr_reader :time_interval
    attr_reader :num_occurrences
        
    def initialize()
      super
      require_relative 'scom_common'
      @exp1_found = false
      @timer = nil
      @lock = Mutex.new
      @counter = 0
    end
        
    def configure(conf)
      super
            
      raise ConfigError, "Configuration does not contain an expression" unless @regexp1
      raise ConfigError, "Configuration does not have corresponding event ID" unless @event_id
      raise ConfigError, "Configuration does not have a time interval" unless (@time_interval > 0)
      raise ConfigError, "Configuration must give a value greater than 0 for num_occurrences" unless (@num_occurrences > 0)
      @key, exp = @regexp1.split(/ /,2)
      raise ConfigError, "regexp1 does not contain 2 parameters" unless exp
      @expression = Regexp.compile(exp)
    end
        
    def flip_state()
      @lock.synchronize {
        @exp1_found = !@exp1_found
      }
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
        flip_state()
        @counter += 1
        $log.debug "Match found for regex #{@regexp1} ID #{@event_id}. Timer Started."
        @timer = Thread.new { sleep @time_interval; timer_expired() }
      elsif @exp1_found and @expression.match(record[key].to_s) 
        @counter += 1
      end # if
      # Check if expected number of occurences reached
      if @counter == @num_occurrences
        # Reset state and counter. Form SCOM event.
        flip_state()
        reset_counter()
        @timer.terminate()
        @timer = nil
        result = SCOM::Common.get_scom_record(time, @event_id, @event_desc)
        $log.debug "Event found for ID #{@event_id}"
      end # if
      result
    end
        
    def timer_expired()
      $log.debug "Timer expired waiting for event ID #{@event_id}"
      flip_state()
      reset_counter()
    end
        
  end # class SCOMRepeatedCorrelationFilter
end # module Fluent



