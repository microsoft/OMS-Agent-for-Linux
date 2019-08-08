# Rather than directly patching desired logic into the fluent log.rb,
# we will patch an import of this file; if future changes are necessary,
# there will be no concern of patch conflict or need for patch file generation.

require_relative 'agent_telemetry_script'

module Fluent
  class Log
    def event(level, args)
      time = Time.now
      message = ''
      map = {}
      args.each {|a|
          if a.is_a?(Hash)
          a.each_pair {|k,v|
            map[k.to_s] = v
          }
        else
          message << a.to_s
        end
      }

      map.each_pair {|k,v|
        message << " #{k}=#{v.inspect}"
      }

      unless @threads_exclude_events.include?(Thread.current)
        record = map.dup
        record.keys.each {|key|
          record[key] = record[key].inspect unless record[key].respond_to?(:to_msgpack)
        }
        record['message'] = message.dup
        @engine.push_log_event("#{@tag}.#{level}", time.to_i, record)

        case Log.str_to_level(level.to_s)
        when LEVEL_ERROR
          OMS::Telemetry.push_qos_event(OMS::LOG_ERROR, "true", message, OMS::INTERNAL)
        when LEVEL_FATAL
          OMS::Telemetry.push_qos_event(OMS::LOG_FATAL, "true", message, OMS::INTERNAL)
        end
      end

      return time, message
    end
  end
end