module OMS
  class Log
    require 'set'
    require 'digest'

    @@error_proc = Proc.new {|message| $log.error message }
    @@warn_proc  = Proc.new {|message| $log.warn message }
    @@info_proc = Proc.new {|message| $log.info message }
    @@debug_proc = Proc.new {|message| $log.debug message }

    @@logged_hashes = Set.new

    class << self
      def error_once(message, tag=nil)
        log_once(@@error_proc, @@debug_proc, message, tag)
      end

      def warn_once(message, tag=nil)
        log_once(@@warn_proc, @@debug_proc, message, tag)
      end

      def info_once(message, tag=nil)
        log_once(@@info_proc, @@debug_proc, message, tag)
      end

      def log_once(first_loglevel_proc, next_loglevel_proc, message, tag=nil)
        # Will log a message once with the first procedure and subsequently with the second
        # This allows repeated messages to be ignored by having the second logging function at a lower log level
        # An optional tag can be used as the message key

        if tag == nil
          tag = message
        end

        md5_digest = Digest::MD5.new
        tag_hash = md5_digest.update(tag).base64digest
        res = @@logged_hashes.add?(tag_hash)

        if res == nil
          # The hash was already in the set
          next_loglevel_proc.call(message)
        else
          # First time we see this hash
          first_loglevel_proc.call(message)
        end
      end
    end # Class methods

  end # Class Log
end # Module OMS
