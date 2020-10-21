# frozen_string_literal: true

module Fluent
  class SyslogSecurityEventsFilter < Filter

    Fluent::Plugin.register_filter('filter_syslog_security', self)

    def initialize
      super
      require_relative 'omslog'
      require_relative 'oms_common'
      require_relative 'security_lib'
    end

    # Interval in seconds to refresh the cache
    config_param :ip_cache_refresh_interval, :integer, :default => 300

    def configure(conf)
      super
      @ip_cache = OMS::IPcache.new @ip_cache_refresh_interval
    end

    def start
      super
    end

    def shutdown
      super
    end

    # For perf debugging
    def check_eps()
      if @eps_counter == nil
        @eps_counter = 0

        @eps_thread = Thread.new {
          current_time = Time.now
          previous_time = current_time
          loop {
            current_time = Time.now
            diff_time_ms = (current_time - previous_time)
            if diff_time_ms >= 1
              $log.info("Security Syslog EPS #{@eps_counter}, for #{diff_time_ms} second")
              @eps_counter = 0
            end
            previous_time = current_time
            sleep 1
          }
        }
      end
      @eps_counter += 1
    end

    def filter(tag, time, record)
      # check_eps()

      # Get the data type name (blob in ODS) from record tag
      # Only records that can be associated to a blob are processed

      # Get the correct identifier from the ident string or nil for unknown identifier
      ident =  OMS::Security.get_ident(record['ident'])
      data_type = OMS::Security.get_data_type(ident)
      return nil if data_type.nil?

      # The tag should looks like this : oms.security.local4.warn
      tags = tag.split('.')
      new_record = {
          'ident' => ident,
          # Use Time.now, because it is the only way to get subsecond precision in version 0.12.
          # The time may be slightly in the future from the ingestion time.
          'Timestamp' => OMS::Common::fast_utc_to_iso8601_format(Time.now.utc),
          'EventTime' => OMS::Common::fast_utc_to_iso8601_format(Time.at(time).utc),
          'Message' => "#{ident}: #{record['message']}",
          'Facility' =>  tags[tags.size - 2],
          'Severity' => tags[tags.size - 1]
      }

      host_ip = @ip_cache.get_ip(record['host'])
      if host_ip.nil?
        OMS::Log.warn_once("Failed to get the IP for #{record['host']}.")
      else
        new_record['HostIP'] = host_ip
      end

      # p record
      wrapper = {
          'DataType' => data_type,
          'IPName' => 'Security',
          'DataItems' => [new_record]
      }

      wrapper
    end
  end
end
