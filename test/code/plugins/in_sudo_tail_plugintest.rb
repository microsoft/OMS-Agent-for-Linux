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
    read_from_head false
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
    assert_equal(false, d.instance.read_from_head)
    assert_equal('/(?<message>.*)/', d.instance.format)
    assert_equal(1, d.instance.run_interval)
  end


  def test_emit
    File.open("#{TMP_DIR}/tail.rb", "w") {|f|
      f.puts "puts \"test1\""
      f.puts "puts \"test2\""
      f.puts "puts \"test2\ttest0\""

    }

    d = create_driver
    d.instance.command = "ruby #{TMP_DIR}/tail.rb "
    d.instance.stubs(:set_system_command).returns(nil)
    emits = []
    # wait 20 * 0.5, "see fluentd/lib/fluent/test/base.rb:79 num_waits.times { sleep 0.05 }
    d.run(num_waits=20) do
      emits = d.emits
    end
    emits = d.emits

    assert_equal(true, emits.length > 0)
    assert_equal({"message"=>"test1"}, emits[0][2])
    assert_equal({"message"=>"test2"}, emits[1][2])
    assert_equal({"message"=>"test2\ttest0"}, emits[2][2])

    assert_equal(3, d.emit_streams.size)
  end

  ### Have to convert the strings to ASCII-8BIT because string comparison of chars > 128 bits only works if both have the same encoding
  ### The message data is converted to UTF-8 in out_oms_blob.rb, before emitting further, using the parse_json_record_encoding method in oms_common library
  ### this plugin only outputs ASCII-8BIT encoded message to the router hence comparing the output with a string of similar encoding. 
  def test_emit_UTF_chars
    File.open("#{TMP_DIR}/tail2.rb", "w") {|f|
      f.puts "puts \"Russia:Россия\""
      f.puts "puts \"Japan:にほん\""
      f.puts "puts \"Registered Sign:\u00ae\""

    }
    d = create_driver
    d.instance.command = "ruby #{TMP_DIR}/tail2.rb "
    d.instance.stubs(:set_system_command).returns(nil)
    emits = []
    # wait 20 * 0.5, "see fluentd/lib/fluent/test/base.rb:79 num_waits.times { sleep 0.05 }
    d.run(num_waits=20) do
      emits = d.emits
    end

    assert_equal(true, emits.length > 0)
    assert_equal({"message".force_encoding("ASCII-8BIT")=>"Russia:Россия".force_encoding("ASCII-8BIT")}, emits[0][2], "Emitted String Encoding is #{emits[0][2]["message"].encoding}")
    assert_equal({"message".force_encoding("ASCII-8BIT")=>"Japan:にほん".force_encoding("ASCII-8BIT")}, emits[1][2])
    assert_equal({"message".force_encoding("ASCII-8BIT")=>"Registered Sign:®".force_encoding("ASCII-8BIT")}, emits[2][2])

    assert_equal(3, d.emit_streams.size)
  end

  def test_emit_multiple_lines
    File.open("#{TMP_DIR}/tail3.rb", "w") {|f|
      f.puts "puts \"test3\""
      f.puts "puts \"test4\ntest5\""
      f.puts "puts \"\ntest6\n\n\ntest7\""
    }

    d = create_driver
    d.instance.command = "ruby #{TMP_DIR}/tail3.rb "
    d.instance.stubs(:set_system_command).returns(nil)
    emits = []
    # wait 20 * 0.5, "see fluentd/lib/fluent/test/base.rb:79 num_waits.times { sleep 0.05 }
    d.run(num_waits=20) do
      emits = d.emits
    end

    assert_equal(true, emits.length > 0)
    assert_equal({"message"=>"test3"}, emits[0][2])
    assert_equal({"message"=>"test4"}, emits[1][2])
    assert_equal({"message"=>"test5"}, emits[2][2])
    assert_equal({"message"=>""}, emits[3][2])
    assert_equal({"message"=>"test6"}, emits[4][2])
    assert_equal({"message"=>""}, emits[5][2])
    assert_equal({"message"=>""}, emits[6][2])
    assert_equal({"message"=>"test7"}, emits[7][2])
  
    assert_equal(8, d.emit_streams.size)
  end

end

