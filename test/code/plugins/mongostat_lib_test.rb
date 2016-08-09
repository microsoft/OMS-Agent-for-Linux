require 'test/unit'
require_relative '../../../source/code/plugins/mongostat_lib'
require_relative 'omstestlib'

class MongostatTest < Test::Unit::TestCase 

  class << self
    def startup
      @@mongostat_lib = MongoStatModule::MongoStat.new
    end

    def shutdown
    end
  end

  def test_filter_null_or_empty_record_returns_empty
    set_fields = "insert query update delete getmore command  mapped  vsize   res faults  qr|qw ar|aw netIn netOut conn     time"
    assert_equal(nil, @@mongostat_lib.transform_and_wrap(set_fields))
    assert_equal(nil, @@mongostat_lib.transform_and_wrap(""))
    assert_equal(nil, @@mongostat_lib.transform_and_wrap(nil))
  end
  
  def test_set_counters_and_values
    $log = OMS::MockLog.new
    set_fields = "insert query update delete getmore command  mapped  vsize   res  faults qr|qw ar|aw netIn netOut conn     time"
    send_values = "    *0    *0     *0     *0       0     2|0  80.0M 358.0M 41.0M   0      0|0   0|0  133b    10k    1 12:29:52"

    @@mongostat_lib.transform_and_wrap(set_fields)
    returned_record = @@mongostat_lib.transform_and_wrap(send_values)
    expected_record = {
             "DataType"=>"LINUX_PERF_BLOB",
             "IPName"=>"LogManagement",
             "DataItems"=> [{
                   "ObjectName"=>"MongoDB",
                   "Collections"=>[
                        {"CounterName"=>"Insert Operations/sec", "Value"=>"0"},
                        {"CounterName"=>"Query Operations/sec", "Value"=>"0"},
                        {"CounterName"=>"Update Operations/sec", "Value"=>"0"},
                        {"CounterName"=>"Delete Operations/sec", "Value"=>"0"},
                        {"CounterName"=>"Total Data Mapped (MB)", "Value"=>"80.0"},
                        {"CounterName"=>"Virtual Memory Process Usage (MB)", "Value"=>"358.0"},
                        {"CounterName"=>"Resident Memory Process Usage (MB)", "Value"=>"41.0"},
                        {"CounterName"=>"Get More Operations/sec", "Value"=>"0"},
                        {"CounterName"=>"Page Faults/sec", "Value"=>"0"},
                        {"CounterName"=>"Total Open Connections", "Value"=>"1"},
                        {"CounterName"=>"Network In (Bytes)", "Value"=>133.0},
                        {"CounterName"=>"Network Out (Bytes)", "Value"=>10240.0},
                        {"CounterName"=>"Active Clients (Read)", "Value"=>"0"},
                        {"CounterName"=>"Active Clients (Write)", "Value"=>"0"},
                        {"CounterName"=>"Queue Length (Read)", "Value"=>"0"},
                        {"CounterName"=>"Queue Length (Write)", "Value"=>"0"},
                        {"CounterName"=>"Local Commands/sec", "Value"=>"2"},
                        {"CounterName"=>"Replicated Commands/sec", "Value"=>"0"}]}]}
    assert_equal(expected_record, record_helper(returned_record))
    $log.clear
  end

  def test_null_counters
    $log = OMS::MockLog.new
    send_values = " nil  nil  nil  nil  nil   nil  nil  nil nil  nil  0|0   0|0  53b    8k    2  12:29:52"  
    returned_counters = @@mongostat_lib.transform_and_wrap(send_values)
    expected_record = {"DataType"=>"LINUX_PERF_BLOB",
                       "IPName"=>"LogManagement",
                       "DataItems"=>[{
                            "ObjectName"=>"MongoDB",
                            "Collections"=>[
                                 {"CounterName"=>"Total Open Connections", "Value"=>"2"},
                                 {"CounterName"=>"Network In (Bytes)", "Value"=>53.0},
                                 {"CounterName"=>"Network Out (Bytes)", "Value"=>8192.0},
                                 {"CounterName"=>"Active Clients (Read)", "Value"=>"0"},
                                 {"CounterName"=>"Active Clients (Write)", "Value"=>"0"},
                                 {"CounterName"=>"Queue Length (Read)", "Value"=>"0"},
                                 {"CounterName"=>"Queue Length (Write)", "Value"=>"0"}]}]}             
    assert_equal(expected_record, record_helper(returned_counters))
    assert($log.logs[0].include?("Dropping null value"))
    $log.clear
  end

  def record_helper(record)
    #strip Timestamp and Hostname keys from dataitems for returned_record
    record["DataItems"].each do |rec|
      rec.tap{ |x| 
        x.delete("Timestamp")
        x.delete("Host")
      }
    end
    return record
  end

end
