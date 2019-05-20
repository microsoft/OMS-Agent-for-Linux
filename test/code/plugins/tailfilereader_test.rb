require 'test/unit'
require_relative '../../../source/code/plugins/tailfilereader.rb'
require 'stringio'
require 'set'

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

  ### Using Set to check if the paths are expanded correctly instead of simply comapring the output array with the file names in order
  ### because of order in which the files are created is not the same as the order in which ruby reads them from the directory
  def test_wildcard_expanded_paths
    files = ["#{TMP_DIR}/tail1.txt", "#{TMP_DIR}/tail2.txt", "#{TMP_DIR}/tail3.txt", "#{TMP_DIR}/tail4.txt"]
    files.each do |f|
      x = File.open(f, 'w')
      x.puts "Test file named - #{f}"
      x.flush
    end
    files_set = Set.new(files)
    checked_set = Set.new
    t = Tailscript::NewTail.new("#{TMP_DIR}/*")
    output = t.expand_paths

    assert_equal(4, output.length, "output is #{output}")
    assert(files_set.include?(output[0]) && !checked_set.include?(output[0]))
    checked_set.add(output[0])
    assert(files_set.include?(output[1]) && !checked_set.include?(output[1]))
    checked_set.add(output[1])
    assert(files_set.include?(output[2]) && !checked_set.include?(output[2]))
    checked_set.add(output[2])
    assert(files_set.include?(output[3]) && !checked_set.include?(output[3]))
  end

  def test_mulitple_paths_delayed_addition
    files = ["#{TMP_DIR}/tail1.txt", "#{TMP_DIR}/tail2.txt", "#{TMP_DIR}/tail3.txt"]
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
    input3 = File.open(files[2], 'w')

    tailreader.start

    input1.puts "test 3"
    input1.flush
    input2.puts "test c"
    input2.flush
    input3.puts "test @"
    input3.puts "test $"
    input3.flush
    input2.puts "test d"
    input2.flush
     
    tailreader.start
    output = $stdout.string.split("\n")

    assert_equal(tailreader.paths, files.join(","))
    assert_equal(5, output.length)
    assert_equal("test 3", output[0])
    assert_equal("test c", output[1])
    assert_equal("test d", output[2])
    assert_equal("test @", output[3])
    assert_equal("test $", output[4])

  end

  def test_mulitple_paths_specific_files_addition
    files = ["#{TMP_DIR}/tail1.txt", "#{TMP_DIR}/tail2.txt", "#{TMP_DIR}/tail3.txt"]
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
    input3 = File.open(files[2], 'w')

    tailreader.start
    #Not adding anything to file 1
    input2.puts "test e"
    input2.flush
    input3.puts "test @"
    input3.puts "test $"
    input3.puts "test %%"
    input3.puts "test &^"
    input3.flush
    input2.puts "test f"
    input2.flush
    
    tailreader.start
    output = $stdout.string.split("\n")

    assert_equal(tailreader.paths, files.join(","))
    assert_equal(6, output.length)
    assert_equal("test e", output[0])
    assert_equal("test f", output[1])
    assert_equal("test @", output[2])
    assert_equal("test $", output[3])
    assert_equal("test %%", output[4])
    assert_equal("test &^", output[5])

  end
end

