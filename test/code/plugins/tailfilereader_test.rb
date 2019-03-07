require 'test/unit'
require_relative '../../../source/code/plugins/tailfilereader.rb'
require 'stringio'

class TailFileReaderTest < Test::Unit::TestCase
  TMP_DIR = File.dirname(__FILE__) + "/../tmp/test_tailfilereader"
  def setup
    FileUtils.rm_rf(TMP_DIR)
    FileUtils.mkdir_p(TMP_DIR)
    @pos_file = "#{TMP_DIR}/tail.pos"
  end

  def teardown
    if TMP_DIR
      FileUtils.rm_rf(TMP_DIR)
    end
  end

  def create(opt={}, file)
    $options = opt
    Tailscript::NewTail.new(file.join(","))
  end

  def test_initialize
    file = ["#{TMP_DIR}/tail.txt"]
    File.open(file[0], "w") 
    tailreader = create({}, file)
    assert_equal(tailreader.paths, "#{TMP_DIR}/tail.txt")
  end
  
  def test_rotate
    file = ["#{TMP_DIR}/tail.txt"]
    tailreader = create({:pos_file => @pos_file}, file)
    $stdout = StringIO.new

    input = File.open(file[0], "w")
    input.puts "test 1"
    input.puts "test 2"
    input.flush

    tailreader.start    
    
    input.puts "test 3"
    input.puts "test 4"
    input.flush
    
    tailreader.start
 
    output = $stdout.string.split("\n")
    assert_equal(2, output.length)
    assert_equal("test 3", output[0])
    assert_equal("test 4", output[1])
  end 

  def test_rotate_readfromhead
    file = ["#{TMP_DIR}/tail.txt"]
    tailreader = create({:pos_file => @pos_file, :read_from_head => true}, file)
    $stdout = StringIO.new

    input = File.open(file[0], "w")
    input.puts "test 1"
    input.puts "test 2"
    input.flush

    input.puts "test 3"
    input.puts "test 4"
    input.flush

    tailreader.start
    output = $stdout.string.split("\n")

    assert_equal(4, output.length)
    assert_equal("test 1", output[0])
    assert_equal("test 2", output[1])
    assert_equal("test 3", output[2])
    assert_equal("test 4", output[3])
  end 

  def test_mulitple_paths
    files = ["#{TMP_DIR}/tail1.txt", "#{TMP_DIR}/tail2.txt"]
    tailreader = create({:pos_file => @pos_file}, files)
    $stdout = StringIO.new

    input1 = File.open(files[0], 'w') 
    input1.puts "test 1"
    input1.puts "test 2"
    input1.flush 

    input2 = File.open(files[1], 'w')
    input2.puts "test a"
    input2.puts "test b"
    input2.flush
    tailreader.start

    input1.puts "test 3"
    input1.flush
    input2.puts "test c"
    input2.flush
     
    tailreader.start
    output = $stdout.string.split("\n")

    assert_equal(tailreader.paths, files.join(","))
    assert_equal(2, output.length)
    assert_equal("test 3", output[0])
    assert_equal("test c", output[1])
  end
end

