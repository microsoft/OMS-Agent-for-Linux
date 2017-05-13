# Develpped by Alessandro Cardoso
# 
# Library for Squid to allow capture Squid statistics
#
module Fluent

#### Log Parser lib - access.log

  class SquidLogParser < Parser
    # Register this parser
    Plugin.register_parser('SquidLogParser', self)

    def initialize
      require 'fluent/parser'
      super
    end

    # This method is called after config_params have read configuration parameters
    def configure(conf)
      super
      @parser = SquidLogParserLib.new(RuntimeError.new) 
    end

    def parse(text)
      time, record = @parser.parse(text)
      yield time, record
    end
  end

  class SquidLoggingBase
     def logerror(text)
     end
  end

  class RuntimeError < SquidLoggingBase
    def logerror(text)
      $log.error "RuntimeError: #{text}"
    end
  end

#### Log Parser lib - access.log

  class SquidLogParserLib
    require 'date'
    require 'etc'
    require_relative 'oms_common'
    require 'fluent/parser'

    def initialize(error_handler)
      @error_handler = error_handler
    end

    REGEX =/(?<eventtime>(\d+))\.\d+\s+(?<duration>(\d+))\s+(?<sourceip>(\d+\.\d+\.\d+\.\d+))\s+(?<cache>(\w+))\/(?<status>(\d+))\s+(?<bytes>(\d+)\s+)(?<response>(\w+)\s+)(?<url>([^\s]+))\s+(?<user>(\w+|\-))\s+(?<method>(\S+.\S+))/

    def parse(line)

      data = {}
      time = Time.now.to_f

      begin
        REGEX.match(line) { |match|
          data['Host'] = OMS::Common.get_hostname

          timestamp = Time.at( match['eventtime'].to_i() )
          data['EventTime'] = OMS::Common.format_time(timestamp)
          data['EventDate'] = timestamp.strftime( '%Y-%m-%d' )
          data['Duration'] = match['duration'].to_i()
          data['SourceIP'] = match['sourceip']
          data['cache'] = match['cache']
          data['status'] = match['status']
          data['bytes'] = match['bytes'].to_i()
          data['httpresponse'] = match['response']
          data['bytes'] = match['bytes'].to_i()
          data['url'] = match['url']
          data['user'] = match['user']
          data['method'] = match['method']
          
        }
      rescue => e
        @error_handler.logerror("Unable to parse the line #{e}")
      end

      return time, data
    end   #def

   end   #class

end  #module
