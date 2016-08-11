module OMS

  class StatsDState
    require_relative 'oms_common'
    require_relative 'omslog'

    public

    def initialize(flush_interval, threshold_percentile, persist_file_location, log)
      @flush_interval = flush_interval
      @threshold_percentile = threshold_percentile
      @persist_file_location = persist_file_location
      @log = log

      @timers = Hash.new { |hash, key| hash[key] = [] }
      @counters = Hash.new { |hash, key| hash[key] = 0 }
      @sets = Hash.new { |hash, key| hash[key] = {} }
      @gauges = nil

      if !@persist_file_location.nil? and File.exist? @persist_file_location
        begin
          file = File.read(@persist_file_location)

          begin
            @gauges = Marshal.load(file)
          rescue => error
            @log.warn "Error parsing file: #{@persist_file_location} : #{error}"
          end
        rescue => error
          @log.warn "Unable to read file: #{@persist_file_location} : #{error}"
        end
      end

      @gauges = Hash.new if @gauges.nil?
    end

    def receive(data)
      return if data.nil?

      data.split("\n").each do |line|
        # expect the line is in the format:
        # <key>:<values>|<type>
        bits = line.split(':')
        key = bits.shift.gsub(/\s+/, '_').gsub(/\//, '-').gsub(/[^a-zA-Z_\-0-9\.]/, '')
        bits.each do |record|
          fields = record.split('|')
          next if fields.nil? || fields.count < 2

          type = fields[1].strip

          if type == 'ms' or type == 't' # timer
            receive_timer(key, fields[0])
          elsif type == 'c' # counter
            receive_counter(key, fields[0])
          elsif type == 's' # set
            receive_set(key, fields[0])
          elsif type == 'g' # gauge
            receive_gauge(key, fields[0])
          else
          end
        end
      end
    end # receive

    def convert_to_oms_format(time, host)
      @log.trace "Begin publish to OMS"

      res = []

      data = aggregate(true)

      base = {
        'Timestamp' => OMS::Common.format_time(time),
        'Host' => host
      }

      @log.trace "Get #{data['timers'].length} timers"

      data['timers'].each do | name, metrics |
        counters = []
        metrics.each do | counter, value |
          counters << { 'CounterName' => counter, 'Value' => value }
        end

        metric = {
          'ObjectName' => 'StatsD Timer',
          'InstanceName' => name,
          'Collections' => counters
        }.merge(base)

        res << metric
      end

      @log.trace "Get #{data['counters'].length} counters"

      data['counters'].each do | name, value |
        metric = {
          'ObjectName' => 'StatsD Counter',
          'InstanceName' => name,
          'Collections' => [{ 'CounterName' => 'rate', 'Value' => value }]
        }.merge(base)

        res << metric
      end

      @log.trace "Get #{data['sets'].length} sets"

      data['sets'].each do | name, value |
        metric = {
          'ObjectName' => 'StatsD Set',
          'InstanceName' => name,
          'Collections' => [{ 'CounterName' => 'count', 'Value' => value }]
        }.merge(base)

        res << metric
      end

      @log.trace "Get #{data['gauges'].length} gauges"

      data["gauges"].each do | name, value |
        metric = {
          'ObjectName' => 'StatsD Gauge',
          'InstanceName' => name,
          'Collections' => [{ 'CounterName' => 'gauge', 'Value' => value }]
        }.merge(base)

        res << metric
      end

      @log.trace "Return #{res.length} metrics"

      res
    end # publish_to_oms

    def aggregate(need_reset = true)
      @log.trace "Aggregate the states"

      timers = @timers.dup
      counters = @counters.dup
      sets = @sets.dup
      gauges = @gauges.dup

      reset if need_reset

      res = { 
        'timers' => aggregate_timers(timers),
        'counters' => aggregate_counters(counters),
        'sets' => aggregate_sets(sets),
        'gauges' => aggregate_gauges(gauges)
      }
    end # aggregate

    private

    def receive_timer(key, values)
      @log.trace "Receive timer: #{key}"

      values.split(',').each do |value|
        v = Float(value.strip) rescue nil
        @timers[key] << v if v
      end
    end # receive_gauge

    def receive_counter(key, value)
      @log.trace "Receive counter: #{key}"

      sample_rate = @flush_interval
      count_str, sample_rate_str = value.split('@', 2)

      if !sample_rate_str.nil? and !sample_rate_str.empty?
        sample_rate = Float(sample_rate_str.strip) rescue @flush_interval
      end

      count = Integer(count_str.strip) rescue 1
      @counters[key] += count.to_i / sample_rate.to_f
    end # receive_gauge

    def receive_set(key, value)
      @log.trace "Receive set: #{key}"

      v = Float(value.strip) rescue nil

      if !v.nil?
        @sets[key][v.to_s] = true
      end
    end # receive_gauge

    def receive_gauge(key, value)
      @log.trace "Receive gauge: #{key}"

      v = Float(value.strip) rescue nil

      if !v.nil? and !(@gauges.has_key?(key) and @gauges[key] == v)
        @gauges[key] = v
        persist_data
      end
    end # receive_gauge

    def persist_data
      if !@persist_file_location.nil?
        begin
          File.open(@persist_file_location, 'w+') do | f |
            f.write(Marshal.dump(@gauges))
          end
        rescue => error
          @log.warn "Unable to persist the data to file: #{@persist_file_location} : #{error}"
        end
      end
    end # persist_gauges

    def aggregate_timers(timers)
      res = {}

      timers.each do | key, values |
        next if values.length == 0

        values.sort!

        count = values.length
        min = values[0]
        max = values[-1]

        mid = (count / 2).round
        median = (count % 2 == 1) ? values[mid] : (values[mid-1] + values[mid]) / 2

        cumulative_values = []
        sum = 0
        values.each do |v|
          sum += v
          cumulative_values << sum
        end

        mean = sum / count

        res[key] = {
          'min' => min,
          'max' => max,
          'sum' => sum,
          'count' => count,
          'mean' => mean,
          'median' => median
        }

        if count > 1 and @threshold_percentile != 100
          threshold_idx = (((100 - @threshold_percentile) / 100.0) * count).round
          num_in_threshold = count - threshold_idx

          next if num_in_threshold < 1

          max_at_threshold = values[num_in_threshold-1]
          sum_in_threshold = cumulative_values[num_in_threshold-1]

          mean = sum_in_threshold / num_in_threshold
          
          mid = (num_in_threshold / 2).round
          median = (num_in_threshold % 2 == 1) ? values[mid] : (values[mid-1] + values[mid]) / 2

          res[key].merge!({
            'max_at_threshold' => max_at_threshold,
            'sum_in_threshold' => sum_in_threshold,
            'count_in_threshold' => num_in_threshold,
            'mean_in_threshold' => mean,
            'median_in_threshold' => median
          })
        end
      end

      res
    end # aggregate_timers

    def aggregate_counters(counters)
      res = {}

      counters.each do | key, value |
        res[key] = value
      end

      res
    end # aggregate_counters

    def aggregate_sets(sets)
      res = {}

      sets.each do | key, value |
        res[key] = value.length
      end

      res
    end # aggregate_sets

    def aggregate_gauges(gauges)
      res = {}

      gauges.each do | key, value |
        res[key] = value
      end

      res
    end # aggregate_guages

    def reset(reset_gauges = false)
      @timers = Hash.new { |hash, key| hash[key] = [] }
      @counters = Hash.new { |hash, key| hash[key] = 0 }
      @sets = Hash.new { |hash, key| hash[key] = {} }
      @gauges = Hash.new { |hash, key| hash[key] = 0 } if reset_gauges
    end # reset

  end # class StatsDAggregator

end # module OMS

