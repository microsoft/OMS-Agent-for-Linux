require_relative '../../../source/ext/fluentd/test/helper'
require 'fluent/test'
require_relative '../../../source/code/plugins/in_auoms'

class AuOMSInputTest < Test::Unit::TestCase
  TMP_DIR = File.dirname(__FILE__) + "/../tmp/in_unix#{ENV['TEST_ENV_NUMBER']}"

  def setup
    Fluent::Test.setup
    FileUtils.rm_rf(TMP_DIR)
    FileUtils.mkdir_p(TMP_DIR)
  end

  CONFIG = %[
    tag test
    path #{TMP_DIR}/unix
    backlog 1000
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::AuOMSInput).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal "#{TMP_DIR}/unix", d.instance.path
    assert_equal 1000, d.instance.backlog
  end

  def connect
    UNIXSocket.new("#{TMP_DIR}/unix")
  end

  def test_time
    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    Fluent::Engine.now = time

    d.expect_emit "test", time, {"a"=>1}
    d.expect_emit "test", time, {"a"=>2}

    d.run do
      d.expected_emits.each {|tag,time,record|
        send_data [0, record].to_json
      }
    end
  end

  def test_message
    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i

    d.expect_emit "test", time, {"a"=>1}
    d.expect_emit "test", time, {"a"=>2}

    d.run do
      d.expected_emits.each {|tag,time,record|
        send_data [time, record].to_json
      }
    end
  end

  def send_data(data)
    io = connect
    begin
      io.write data
    ensure
      io.close
    end
  end
end
