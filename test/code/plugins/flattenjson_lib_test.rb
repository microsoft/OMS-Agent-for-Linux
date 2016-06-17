require 'test/unit'

require_relative '../../../source/code/plugins/flattenjson_lib'
require_relative 'omstestlib'

class FlattenJsonTest < Test::Unit::TestCase
  class << self
    def startup
      @@flattenjson_lib = OMS::FlattenJson.new
    end

    def shutdown
    end
  end

  class MockEventStream
    def initialize
      @data = []
    end

    def add(time, record)
      @data << [time, record]
    end

    def get(index)
      @data[index]
    end

    def length
      @data.length
    end

    def clear
      @data = []
    end
  end

  def setup
    $log = OMS::MockLog.new
    $es = MockEventStream.new
  end

  def teardown
  end

  def test_flatten_target_array
    record = { 'root' => { 'target' => [ {'a' => 'b', 'c' => {'d' => 'e'}, 'f' => [ 1, 2, 3] }, { 'g' => { 'h' => [ {'i' => 4 }, { 'j' => 5 } ] }} ] } }
    @@flattenjson_lib.select_split_flatten(nil, record, 'record["root"]["target"]', $es)

    assert_equal(2, $es.length, "Expect 2 record");
    assert_equal(2, $es.get(0).length, "Expect a tuple");
    assert_equal(2, $es.get(1).length, "Expect a tuple");
    assert_equal('{"a"=>"b", "c_d"=>"e", "f_0"=>1, "f_1"=>2, "f_2"=>3}', $es.get(0)[1].to_s, "Unexpected result: #{$es.get(0)[1]}")
    assert_equal('{"g_h_0_i"=>4, "g_h_1_j"=>5}', $es.get(1)[1].to_s, "Unexpected result: #{$es.get(1)[1]}")
  end

  def test_flatten_target_hash
    record = { 'root' => { 'target' => {'a' => 'b', 'c' => {'d' => 'e'}, 'f' => [ 1, 2, 3] } } }
    @@flattenjson_lib.select_split_flatten(nil, record, 'record["root"]["target"]', $es)

    assert_equal(1, $es.length, "Expect 1 record");
    assert_equal(2, $es.get(0).length, "Expect a tuple");
    assert_equal('{"a"=>"b", "c_d"=>"e", "f_0"=>1, "f_1"=>2, "f_2"=>3}', $es.get(0)[1].to_s, "Unexpected result: #{$es.get(0)[1]}")
  end

  def test_nil_select_typeerror
    assert_nothing_raised(RuntimeError, "No error should be raised") do
      @@flattenjson_lib.select_split_flatten(nil, nil, nil, $es)
    end

    assert_not_equal(0, $log.logs, "No log is found")
    assert($log.logs[0].include?("Invalid select: "))

    assert_equal(1, $es.length, "Expect 1 record");
    assert_equal(2, $es.get(0).length, "Expect a tuple");
    assert_equal({}, $es.get(0)[1], "Result should be empty: #{$es.get(0)[1]}")
  end

  def test_wrong_select_nameerror
    assert_nothing_raised(RuntimeError, "No error should be raised") do
      @@flattenjson_lib.select_split_flatten(nil, nil, 'records', $es)
    end

    assert_not_equal(0, $log.logs, "No log is found")
    assert($log.logs[0].include?("Invalid select: "))

    assert_equal(1, $es.length, "Expect 1 record");
    assert_equal(2, $es.get(0).length, "Expect a tuple");
    assert_equal({}, $es.get(0)[1], "Result should be empty: #{$es.get(0)[1]}")
  end

  def test_nil_record_no_error
    assert_nothing_raised(RuntimeError, "No error should be raised") do
      @@flattenjson_lib.select_split_flatten(nil, nil, 'record', $es)
    end

    assert($log.logs.empty?, "No log should be found")

    assert_equal(1, $es.length, "Expect 1 record");
    assert_equal(2, $es.get(0).length, "Expect a tuple");
    assert_equal({}, $es.get(0)[1], "Result should be empty: #{$es.get(0)[1]}")
  end

  def test_nil_root
    record = { 'a' => 'b' }
    assert_nothing_raised(RuntimeError, "No error should be raised") do
      @@flattenjson_lib.select_split_flatten(nil, record, 'record["root"]', $es)
    end

    assert($log.logs.empty?, "No log should be found")

    assert_equal(1, $es.length, "Expect 1 record");
    assert_equal(2, $es.get(0).length, "Expect a tuple");
    assert_equal({}, $es.get(0)[1], "Result should be empty: #{$es.get(0)[1]}")
  end

  def test_nil_target
    record = { 'a' => 'b' }
    assert_nothing_raised(RuntimeError, "No error should be raised") do
      @@flattenjson_lib.select_split_flatten(nil, record, 'record["root"]["target"]', $es)
    end

    assert_not_equal(0, $log.logs, "No log is found")
    assert($log.logs[0].include?("Invalid select: "))

    assert_equal(1, $es.length, "Expect 1 record");
    assert_equal(2, $es.get(0).length, "Expect a tuple");
    assert_equal({}, $es.get(0)[1], "Result should be empty: #{$es.get(0)[1]}")
  end
end


