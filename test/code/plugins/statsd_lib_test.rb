require 'tempfile'
require 'test/unit'
require_relative '../../../source/code/plugins/statsd_lib'
require_relative 'omstestlib'

class StatsdTest < Test::Unit::TestCase

  class OMS::StatsDState
    def FlushInterval=(value)
      @flush_interval = value
    end

    def ThresholdPercentile=(value)
      @threshold_percentile = value
    end

    def PersistFileLocation=(value)
      @persist_file_location = value
    end
  end

  def setup
    @flush_interval = 10
    @threshold_percentile = 80
    @log = OMS::MockLog.new
    @persist_tempfile = Tempfile.new('statsd.data')
    @statsd_lib = OMS::StatsDState.new(@flush_interval, @threshold_percentile, @persist_tempfile.path, @log)
  end

  def teardown
    @persist_tempfile.unlink
  end

  def test_boundaries
    assert_nothing_raised(RuntimeError, "Failed to handle the empty case") do
      @statsd_lib.receive(nil)
      @statsd_lib.receive('')
    end
  end

  def test_invalid_inputs
    assert_nothing_raised(RuntimeError, "Failed to handle invalid inputs") do
      @statsd_lib.receive('abdasdfasdf')
      @statsd_lib.receive('abda:1|a')
      @statsd_lib.receive('abdasdf:1')
      @statsd_lib.receive('abdasdfas:abcd|g')
    end
  end

  def test_gauge_not_reset
    @statsd_lib.receive('sample.gauge:314|g')
    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['gauges'].nil?, 'gauges should not be nil')
    assert_equal(314, metrics['gauges']['sample.gauge'], 'sample.gauge value should match')

    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['gauges'].nil?, 'gauges should not be nil')
    assert_equal(314, metrics['gauges']['sample.gauge'], 'sample.gauge value should not be reset')
  end

  def test_gauge_persist_and_2gauges
    @statsd_lib.receive('sample.gauge:1|g')
    @statsd_lib.receive('sample.gauge:159|g')
    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['gauges'].nil?, 'gauges should not be nil')
    assert_equal(159, metrics['gauges']['sample.gauge'], 'sample.gauge value should updated')

    new_statsd_lib = OMS::StatsDState.new(10, 90, @persist_tempfile.path, @log)
    metrics = new_statsd_lib.aggregate(true)
    assert(!metrics['gauges'].nil?, 'gauges should not be nil')
    assert_equal(159, metrics['gauges']['sample.gauge'], 'sample.gauge value should be persisted')

    @statsd_lib.receive('sample.gauge2:265|g')
    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['gauges'].nil?, 'gauges should not be nil')
    assert_equal(159, metrics['gauges']['sample.gauge'], 'sample.gauge value should not change')
    assert_equal(265, metrics['gauges']['sample.gauge2'], 'sample.gauge2 value should be set')
  end

  def test_counter_and_reset
    @statsd_lib.receive('sample.counter:1|c')
    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['counters'].nil?, 'counters should not be nil')
    assert_equal(1.0 / @flush_interval, metrics['counters']['sample.counter'], 'sample.counter value should match')

    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['counters'].nil?, 'counters should not be nil')
    assert(metrics['counters']['sample.counter'].nil?, 'sample.counter value should be reset')
  end

  def test_counter_expressions
    @statsd_lib.receive('sample.counter:1|c')
    @statsd_lib.receive('sample.counter:2|c')
    @statsd_lib.receive('sample.counter:3@4|c')
    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['counters'].nil?, 'counters should not be nil')
    assert_equal( ( 1.0 + 2 ) / @flush_interval + 3.0 / 4, metrics['counters']['sample.counter'], 'sample.counter value should match')
  end

  def test_2counters
    @statsd_lib.receive('sample.counter:5|c')
    @statsd_lib.receive('sample.counter:6|c')
    @statsd_lib.receive('sample.counter2:7@8|c')
    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['counters'].nil?, 'counters should not be nil')
    assert_equal( ( 5.0 + 6 ) / @flush_interval, metrics['counters']['sample.counter'], 'sample.counter value should match')
    assert_equal( 7.0 / 8, metrics['counters']['sample.counter2'], 'sample.counter2 value should match')
  end

  def test_set_and_reset
    @statsd_lib.receive('sample.set:233333|s')
    @statsd_lib.receive('sample.set:233333|s')
    @statsd_lib.receive('sample.set:233333|s')
    @statsd_lib.receive('sample.set:1111111111111111111111|s')
    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['sets'].nil?, 'sets should not be nil')
    assert_equal(2, metrics['sets']['sample.set'], 'sample.set value should match')

    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['sets'].nil?, 'sets should not be nil')
    assert(metrics['sets']['sample.set'].nil?, 'sample.set value should be reset')
  end

  def test_2sets
    @statsd_lib.receive('sample.set:233333|s')
    @statsd_lib.receive('sample.set2:233333|s')
    @statsd_lib.receive('sample.set:233333|s')
    @statsd_lib.receive('sample.set:1111111111111111111111|s')
    @statsd_lib.receive('sample.set2:0|s')
    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['sets'].nil?, 'sets should not be nil')
    assert_equal(2, metrics['sets']['sample.set'], 'sample.set value should match')
    assert_equal(2, metrics['sets']['sample.set2'], 'sample.set2 value should match')
  end

  def test_timer_and_reset
    rng = Random.new(Random.new_seed)

    timers = Array.new(rng.rand(100).round+100) { |i| rng.rand(1000).round }

    sum = 0.0
    timers.each do |t|
      sum += t
      @statsd_lib.receive("sample.timer:#{t}|ms")
    end

    timers.sort!

    count = timers.length
    mean = sum / count

    mid = (count / 2).round
    median = (count % 2 == 1) ? timers[mid] : (timers[mid-1] + timers[mid]) / 2.0

    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['timers'].nil?, 'timers should not be nil')
    assert(!metrics['timers']['sample.timer'].nil?, 'sample.timer should not be nil')
    assert_equal(timers[0], metrics['timers']['sample.timer']['min'], 'sample.timer max should match')
    assert_equal(timers[-1], metrics['timers']['sample.timer']['max'], 'sample.timer min should match')
    assert_equal(sum, metrics['timers']['sample.timer']['sum'], 'sample.timer sum should match')
    assert_equal(count, metrics['timers']['sample.timer']['count'], 'sample.timer count should match')
    assert_equal(mean, metrics['timers']['sample.timer']['mean'], 'sample.timer mean should match')
    assert_equal(median, metrics['timers']['sample.timer']['median'], 'sample.timer median should match')

    threshold_idx = (((100 - @threshold_percentile) / 100.0) * count).round
    num_in_threshold = count - threshold_idx

    sum = 0.0
    timers[0..num_in_threshold-1].each { |t| sum += t }

    mean = sum / num_in_threshold

    mid = (num_in_threshold / 2).round
    median = (num_in_threshold % 2 == 1) ? timers[mid] : (timers[mid-1] + timers[mid]) / 2.0

    assert_equal(timers[num_in_threshold-1], metrics['timers']['sample.timer']['max_at_threshold'], 'sample.timer max_at_threshold should match')
    assert_equal(sum, metrics['timers']['sample.timer']['sum_in_threshold'], 'sample.timer sum_in_threshold should match')
    assert_equal(num_in_threshold, metrics['timers']['sample.timer']['count_in_threshold'], 'sample.timer count_in_threshold should match')
    assert_equal(mean, metrics['timers']['sample.timer']['mean_in_threshold'], 'sample.timer mean_in_threshold should match')
    assert_equal(median, metrics['timers']['sample.timer']['median_in_threshold'], 'sample.timer median_in_threshold should match')

    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['timers'].nil?, 'timers should not be nil')
    assert(metrics['timers']['sample.timer'].nil?, 'sample.timer value should be reset')
  end

  def test_timers_expressions
    @statsd_lib.receive("sample.timer:123|ms")
    @statsd_lib.receive("sample.timer:123|t")
    @statsd_lib.receive("sample.timer:456|t")
    @statsd_lib.receive("sample.timer:789|ms")
    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['timers'].nil?, 'timers should not be nil')
    assert(!metrics['timers']['sample.timer'].nil?, 'sample.timer should not be nil')
    assert_equal(123, metrics['timers']['sample.timer']['min'], 'sample.timer max should match')
    assert_equal(789, metrics['timers']['sample.timer']['max'], 'sample.timer min should match')
    assert_equal(1491, metrics['timers']['sample.timer']['sum'], 'sample.timer sum should match')
    assert_equal(4, metrics['timers']['sample.timer']['count'], 'sample.timer count should match')
    assert_equal(372.75, metrics['timers']['sample.timer']['mean'], 'sample.timer mean should match')
    assert_equal(289.5, metrics['timers']['sample.timer']['median'], 'sample.timer median should match')
  end

  def test_2timers
    @statsd_lib.receive("sample.timer:123|ms")
    @statsd_lib.receive("sample.timer2:123|t")
    @statsd_lib.receive("sample.timer:456|t")
    @statsd_lib.receive("sample.timer2:789|ms")
    metrics = @statsd_lib.aggregate(true)
    assert(!metrics['timers'].nil?, 'timers should not be nil')
    assert(!metrics['timers']['sample.timer'].nil?, 'sample.timer should not be nil')
    assert_equal(123, metrics['timers']['sample.timer']['min'], 'sample.timer max should match')
    assert_equal(456, metrics['timers']['sample.timer']['max'], 'sample.timer min should match')
    assert_equal(579, metrics['timers']['sample.timer']['sum'], 'sample.timer sum should match')
    assert_equal(2, metrics['timers']['sample.timer']['count'], 'sample.timer count should match')
    assert_equal(289.5, metrics['timers']['sample.timer']['mean'], 'sample.timer mean should match')
    assert_equal(289.5, metrics['timers']['sample.timer']['median'], 'sample.timer median should match')
    assert(!metrics['timers'].nil?, 'timers should not be nil')
    assert(!metrics['timers']['sample.timer2'].nil?, 'sample.timer2 should not be nil')
    assert_equal(123, metrics['timers']['sample.timer2']['min'], 'sample.timer2 max should match')
    assert_equal(789, metrics['timers']['sample.timer2']['max'], 'sample.timer2 min should match')
    assert_equal(912, metrics['timers']['sample.timer2']['sum'], 'sample.timer2 sum should match')
    assert_equal(2, metrics['timers']['sample.timer2']['count'], 'sample.timer2 count should match')
    assert_equal(456, metrics['timers']['sample.timer2']['mean'], 'sample.timer2 mean should match')
    assert_equal(456, metrics['timers']['sample.timer2']['median'], 'sample.timer2 median should match')
  end

  def test_publish_to_oms_with_mixed_value
    @statsd_lib.receive('sample.gauge:1|g')
    @statsd_lib.receive('sample.gauge:159|g')
    @statsd_lib.receive('sample.counter:1|c')
    @statsd_lib.receive('sample.counter:2|c')
    @statsd_lib.receive('sample.counter:3@4|c')
    @statsd_lib.receive('sample.set:233333|s')
    @statsd_lib.receive('sample.set:233333|s')
    @statsd_lib.receive('sample.set:233333|s')
    @statsd_lib.receive('sample.set:1111111111111111111111|s')
    @statsd_lib.receive("sample.timer:123|ms")
    @statsd_lib.receive("sample.timer:123|t")
    @statsd_lib.receive("sample.timer:456|t")
    @statsd_lib.receive("sample.timer:789|ms")

    t = 1470369495.181262
    data = @statsd_lib.convert_to_oms_format(t, 'testhost123')
    expected = [{
      "Collections"=>[
        {"CounterName"=>"min", "Value"=>123.0},
        {"CounterName"=>"max", "Value"=>789.0},
        {"CounterName"=>"sum", "Value"=>1491.0},
        {"CounterName"=>"count", "Value"=>4},
        {"CounterName"=>"mean", "Value"=>372.75},
        {"CounterName"=>"median", "Value"=>289.5},
        {"CounterName"=>"max_at_threshold", "Value"=>456.0},
        {"CounterName"=>"sum_in_threshold", "Value"=>702.0},
        {"CounterName"=>"count_in_threshold", "Value"=>3},
        {"CounterName"=>"mean_in_threshold", "Value"=>234.0},
        {"CounterName"=>"median_in_threshold", "Value"=>123.0}
      ],
      "Host"=>"testhost123",
      "InstanceName"=>"sample.timer",
      "ObjectName"=>"StatsD Timer",
      "Timestamp"=>"2016-08-05T03:58:15.181Z"
    },
    {
      "Collections"=>[{"CounterName"=>"rate", "Value"=>1.05}],
      "Host"=>"testhost123",
      "InstanceName"=>"sample.counter",
      "ObjectName"=>"StatsD Counter",
      "Timestamp"=>"2016-08-05T03:58:15.181Z"
    },
    {
      "Collections"=>[{"CounterName"=>"count", "Value"=>2}],
      "Host"=>"testhost123",
      "InstanceName"=>"sample.set",
      "ObjectName"=>"StatsD Set",
      "Timestamp"=>"2016-08-05T03:58:15.181Z"
    },
    {
      "Collections"=>[{"CounterName"=>"gauge", "Value"=>159.0}],
      "Host"=>"testhost123",
      "InstanceName"=>"sample.gauge",
      "ObjectName"=>"StatsD Gauge",
      "Timestamp"=>"2016-08-05T03:58:15.181Z"
    }]

    assert_equal(expected, data, 'data is not expected')
  end
end
