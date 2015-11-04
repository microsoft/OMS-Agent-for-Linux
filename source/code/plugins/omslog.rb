class OMS_Log

  def initialize
    require 'set'
    require 'digest'
    @logged_hashes = Set.new
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
    res = @logged_hashes.add?(tag_hash)

    if res == nil
      # The hash was already in the set
      next_loglevel_proc.call(message)
    else
      # First time we see this hash
      first_loglevel_proc.call(message)
    end
  end

end
