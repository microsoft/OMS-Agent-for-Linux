module AuditLogModule
  class LoggingBase
    def log_error(text)
    end
  end

  class RuntimeError < LoggingBase
    def log_error(text)
      $log.error "RuntimeError: #{text}"
    end
  end

  class AuditLogParser
    require 'date'
    require 'etc'
    require 'digest'
    require_relative 'oms_common'

    def initialize(error_handler)
      @error_handler = error_handler
      @sha256 = Digest::SHA256.new
    end

    SKETCH_REGEX = /type=(?<record>[A-Z_]+) msg=audit\((?<audit_id>(?<time_epoch>[0-9\.]+):(?<serial_number>[0-9]+))\): (?<additional_fields>.+)/
    ADDITIONAL_MSG_REGEX = /(?<additional_msg>^[^=]+) [a-z0-1_\-]+=/
    FIELDS_REGEX = /(msg=')?([a-z0-9_\-]+)=("[^"]*"|'[^']*'|[^ ]*)?/

    def parse(line)
      data = {}
      time = Time.now.to_f

      begin
        SKETCH_REGEX.match(line) { |match|
          data['Computer'] = OMS::Common.get_hostname
          data['RecordType'] = match['record']
          data['AuditID'] = match['audit_id']
          time = match['time_epoch'].to_f
          data['Timestamp'] = OMS::Common.format_time(time)
          data['SerialNumber'] = match['serial_number']
          additional_fields = match['additional_fields']
        
          # process the message before the first field
          ADDITIONAL_MSG_REGEX.match(additional_fields) { |m|
            data['AdditionalMessage'] = m['additional_msg']
          }
        
          additional_fields.scan(FIELDS_REGEX) { |m|
            name = m[1]
            value = strip_quotes(m[2])
            data[name] = get_typed_value(name, value)
            friendly_name, readable_value = translate(name, value)
            data[friendly_name] = readable_value if !readable_value.nil?
          }
          data['Hash'] = @sha256.hexdigest line
        }
      rescue => e
        @error_handler.log_error("Unable to parse the line #{e}")
      end

      return time, data
    end
    

    private

    def strip_quotes(value)
      if value.start_with?('"') or value.start_with?("'")
        value = value[1..-1]
      end
    
      if value.end_with?('"') or value.end_with?("'")
        value = value[0..-2]
      end
    
      return value
    end
    
    USER_ID_FIELDS_MAPPING = {
      'uid' => 'user_name',
      'auid' => 'audit_user',
      'euid' => 'effective_user',
      'suid' => 'set_user',
      'fsuid' => 'filesystem_user',
      'inode_uid' => 'inode_user',
      'oauid' => 'o_audit_user',
      'ouid' => 'o_user_name',
      'obj_uid' => 'obj_user',
      'sauid' => 'sender_audit_user'
    }
    
    GROUP_ID_FIELDS_MAPPING = {
      'gid' => 'group_name',
      'egid' => 'effective_group',
      'fsgid' => 'filesystem_group',
      'inode_gid' => 'inode_group',
      'new_gid' => 'new_group',
      'obj_gid' => 'obj_group',
      'ogid' => 'owner_group',
      'sgid' => 'set_group'
    }
    
    PROCESS_ID_FIELDS_MAPPING = {
      'pid' => 'process_name',
      'opid' => 'o_process_name',
      'ppid' => 'parent_process'
    }

    def translate(name, value)
      begin
        if PROCESS_ID_FIELDS_MAPPING.has_key? name
          return PROCESS_ID_FIELDS_MAPPING[name], get_process_name_by_id(value)
        end
      
        if USER_ID_FIELDS_MAPPING.has_key? name
          return USER_ID_FIELDS_MAPPING[name], get_user_name_by_id(value.to_i)
        end
      
        if GROUP_ID_FIELDS_MAPPING.has_key? name
          return GROUP_ID_FIELDS_MAPPING[name], get_group_name_by_id(value.to_i)
        end
      rescue => e
        # type doesn't match
        @error_handler.log_error("Unable to translate the field: '#{name}': '#{value}'. Message: #{e}")
      end
    end
    
    def get_typed_value(name, value)
      # determine the type of the value by name and convert
      return value
    end
    
    def get_process_name_by_id(pid)
      begin
        return IO.read("/proc/#{pid}/cmdline").tr("\0", ' ').strip
      rescue
        # Process terminated
      end
    end
    
    def get_user_name_by_id(uid)
      return 'unset' if uid == 0xffffffff
    
      begin
        return Etc.getpwuid(uid).name
      rescue
        # User not exists
      end
    end
    
    def get_group_name_by_id(gid)
      return 'unset' if gid == 0xffffffff
    
      begin
        return Etc.getgrgid(gid).name
      rescue
        # Group not exists
      end
    end

  end
end
