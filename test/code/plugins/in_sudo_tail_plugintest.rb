require_relative '../../../source/ext/fluentd/test/helper'
require 'fluent/test'
require_relative '../../../source/code/plugins/in_sudo_tail'
require 'mocha/test_unit'

class SudoTailTest < Test::Unit::TestCase
  TMP_DIR = File.dirname(__FILE__) + "/../tmp/tail#{ENV['TEST_ENV_NUMBER']}"

  def setup
    Fluent::Test.setup
    FileUtils.rm_rf(TMP_DIR)
    FileUtils.mkdir_p(TMP_DIR)
  end

  def teardown
    #super
    if TMP_DIR
      FileUtils.rm_rf(TMP_DIR)
    end
    Fluent::Engine.stop
  end

  CONFIG = %[
    path #{TMP_DIR}/tail.txt
    tag t1
    pos_file #{TMP_DIR}/tail.pos
    read_from_head true
    format /(?<message>.*)/
    run_interval 1s
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::SudoTail).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal("#{TMP_DIR}/tail.txt", d.instance.path)
    assert_equal("t1", d.instance.tag)
    assert_equal("#{TMP_DIR}/tail.pos", d.instance.pos_file)
    assert_equal(true, d.instance.read_from_head)
    assert_equal('/(?<message>.*)/', d.instance.format)
    assert_equal(1, d.instance.run_interval)
  end


  def test_emit
    File.open("#{TMP_DIR}/tail.rb", "w") {|f|
      f.puts "puts \"test1\""
      f.puts "puts \"test2\""
    }

    d = create_driver
    d.instance.command = "ruby #{TMP_DIR}/tail.rb "
    d.instance.stubs(:set_system_command).returns(nil)
    d.run
    emits = d.emits

    assert_equal(true, emits.length > 0)
    assert_equal({"message"=>"test1"}, emits[0][2])
    assert_equal({"message"=>"test2"}, emits[1][2])
    assert_equal(2, d.emit_streams.size)
  end

end

