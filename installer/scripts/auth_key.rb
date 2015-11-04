require 'digest'
require 'openssl'
require 'base64'

def get_content_hash(file_path)
  raise "Error : #{file_path} is not a file" unless File.file?(file_path)
  return Digest::SHA256.file(file_path).base64digest
end

def get_auth_key(date_str, content_hash, shared_key_path)
  raise "Error content hash lenght should be 44 characters long but is #{content_hash.size}" if content_hash.size != 44
  raise "Error : #{shared_key_path} is not a file" unless File.file?(shared_key_path)
  digest = OpenSSL::Digest.new('sha256')
  shared_key = IO.read(shared_key_path)
  key_decoded = Base64.decode64(shared_key)
  data = "#{date_str}\n#{content_hash}\n"

  hmac = OpenSSL::HMAC.digest(digest, key_decoded, data)
  return Base64.encode64(hmac).strip
end

def get_auth_str(date_str, file_path, shared_key_path)
  content_hash = get_content_hash(file_path)
  auth_key = get_auth_key(date_str, content_hash, shared_key_path)
  return "#{content_hash} #{auth_key}" 
end

def print_auth(date_str, file_path, shared_key_path)
  print get_auth_str(date_str, file_path, shared_key_path)
end

if __FILE__ == $0
  raise "Expecting 3 parameters but got #{ARGV.size}" if ARGV.size != 3
  date_str        = ARGV[0] # "2015-10-09T14:58:51.746850300-07:00"
  body_path       = ARGV[1] # "body_onboard.xml"
  # Shared key looks like : "qoWgVB0a1393p4FUncrY2nc/U1/CkOYlXz3ok3Oe79gSB6NLa853hiQzcwcyBb10Rjj7iswRvoJGtLJUD/o/yw=="
  shared_key_path = ARGV[2] # "shared_key_file"
  print_auth(date_str, body_path, shared_key_path)
end
