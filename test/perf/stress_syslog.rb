require 'syslog/logger'

# Parse the first argument as the number of syslog events to generate
log_count = ARGV.size() >= 1 ? ARGV[0].to_i : 100

log = Syslog::Logger.new 'stress_syslog'
for i in 1..log_count
  # Generate a random message for each syslog event
  msg = "#{i}:#{('a'..'z').to_a.shuffle[0,8].join}"
  # Ruby seems to have a bug : the error severity level appears as a warning in syslog 
  log.error msg
end
