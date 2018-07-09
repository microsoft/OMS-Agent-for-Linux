require 'test/unit'
require_relative '../../../source/code/plugins/oms_omi_lib'
require_relative 'omstestlib'

class In_OMS_OMI_Test < Test::Unit::TestCase
  
  class MockOmiInterface
    attr_accessor :omi_result
    attr_reader :called_connect
    attr_reader :called_disconnect

    def initialize
      @called_connect = false
      @called_disconnect = false
    end
    
    def enumerate(items)
      return @omi_result
    end

    def connect
      @called_connect = true
    end

    def disconnect
      @called_disconnect = true
    end
  end

  class MockCommon
    class << self
      def get_hostname
        return 'MockHostname'
      end
    end
  end

  def setup
    $log = OMS::MockLog.new
    set_static_mock_data
    @mock = MockOmiInterface.new
    @common = MockCommon
    @mapping_path = "#{ENV['BASE_DIR']}/installer/conf/omi_mapping.json"
  end

  def teardown
    # Yay garbage collector
  end

  def test_get_specific_mapping
    oms_object_names = ['Processor', 'Logical Disk', 'Memory', 'Physical Disk', 'System', 'Process', 'Container', 'Apache HTTP Server',
                        'Apache Virtual Host', 'MySQL Database', 'MySQL Server']
    oms_object_names.each { |name| validate_specific_mapping(name) }
  end

  def validate_specific_mapping(object_name, mapping=@mapping_path)
    omilib = OmiOms.new(object_name, 'inst_regex', 'counter_regex', mapping, @mock)

    assert_equal([], $log.logs, "There was an error creating omilib")
    assert_not_equal(nil, omilib.specific_mapping, "Specific mapping should not be null for '#{object_name}'")

    # Is it the right mapping?
    assert_equal(object_name, omilib.specific_mapping["ObjectName"], "Did not receive the appropriate mapping")

    # Does it have all the expected keys?
    expected_keys = ["CimClassName", "ObjectName", "InstanceProperty", "Namespace","CimProperties"]
    expected_keys.each { |key| assert(omilib.specific_mapping.has_key?(key), "Could not find key '#{key}' for '#{object_name}' mapping") }
    # Is there a value for each key?
    expected_keys.each { |key| assert(omilib.specific_mapping[key].size > 0, "Empty value for '#{object_name}', key : '#{key}'") }

    # Does it have only the keys we are testing for? If not, the test data should be updated
    assert_equal(expected_keys, omilib.specific_mapping.keys, "Found unexpected keys in the mapping.")
  end

  def test_invalid_mapping_file
    fake_mapping_path = "#{@mapping_path}.fake"
    assert_equal(false, File.file?(fake_mapping_path), "The file '#{fake_mapping_path}' should not exist for this test")
    omilib = OmiOms.new('Processor', 'inst_regex', 'counter_regex', fake_mapping_path, @mock)
    assert_equal(["Unable to read file #{fake_mapping_path}"], $log.logs, "Did not get the expected errror")
    assert_equal(nil, omilib.specific_mapping, "The specific mapping should be null")
  end

  def test_invalid_object_name
    fake_object_name = 'Blablabla'
    omilib = OmiOms.new(fake_object_name, 'inst_regex', 'counter_regex', @mapping_path, @mock)
    assert_equal(nil, omilib.specific_mapping, "Specific mapping should not be null for '#{fake_object_name}'")
    assert_equal(["Could not find ObjectName '#{fake_object_name}' in #{@mapping_path}"], $log.logs, "Did not get the expected error")
    $log.clear

    # Make sure enumerate does not fail badly
    result = omilib.enumerate(Time.now)
    assert_equal(nil, result, "Enumerate should fail with the invalid object name '#{fake_object_name}'")
    assert_equal([], $log.logs, "There shouldn't be a second error generated when enumerate is called")
  end

  def test_get_cim_to_oms_mappings
    omilib = OmiOms.new('Apache HTTP Server', 'inst_regex', 'counter_regex', @mapping_path, @mock)
    
    cim_properties = [{
                        "CimPropertyName"=> "TotalPctCPU",
                        "CounterName"=> "Total Pct CPU"
                      },
                      {
                        "CimPropertyName"=> "IdleWorkers",
                        "CounterName"=> "Idle Workers"
                      },
                      {
                        "CimPropertyName"=> "BusyWorkers",
                        "CounterName"=> "Busy Workers"
                      },
                      {
                        "CimPropertyName"=> "PctBusyWorkers",
                        "CounterName"=> "Pct Busy Workers"
                      }]

    cim_to_oms = omilib.get_cim_to_oms_mappings(cim_properties)
    expected = {"TotalPctCPU"=>"Total Pct CPU", "IdleWorkers"=>"Idle Workers", "BusyWorkers"=>"Busy Workers", "PctBusyWorkers"=>"Pct Busy Workers"}
    assert_equal(expected, cim_to_oms, "Did not generate the correct mapping of CIM to OMS properties")
  end
    
  def test_enumerate_filtering
    @mock.omi_result = @OMI_result_logical_disk
    omilib = OmiOms.new('Logical Disk', '_Total', '%', @mapping_path, @mock, @common)
    
    time = Time.parse('2015-10-21 16:21:19 -0700')
    result = omilib.enumerate(time)
    assert_not_equal(nil, result, "Enumerate failed unexpectedly")
    assert_equal(@OMS_result_logical_disk_filter, result, "The result of enumerate differs from the expected result")
  end

  def test_enumerate_bad_regex
    @mock.omi_result = @OMI_result_logical_disk
    omilib = OmiOms.new('Logical Disk', '*', '*', @mapping_path, @mock)
    time = Time.parse('2015-10-21 16:21:19 -0700')
    result = omilib.enumerate(time)
    assert_equal(nil, result, "Enumerate should fail with a bad regex")
    assert_equal(["Regex error on instance_regex : target of repeat operator is not specified: /*/"], $log.logs)
    
    # We should not generate duplicate errors
    $log.clear
    result = omilib.enumerate(time)
    assert_equal(nil, result, "Enumerate should fail with a bad regex")
    assert_equal([], $log.logs, "There shouldn't be errors generated the second time enumerate is called")
  end

  def test_enumerate_filtering_or
    @mock.omi_result = @OMI_result_logical_disk
    omilib = OmiOms.new('Logical Disk', '/', '%|Disk', @mapping_path, @mock, @common)

    time = Time.parse('2015-10-21 16:21:19 -0700')
    result = omilib.enumerate(time)
    assert_equal(@OMS_result_logical_disk_or, result, "The result of enumerate differs from the expected result")
  end

  def test_enumerate_filtering_all
    @mock.omi_result = @OMI_result_logical_disk
    omilib = OmiOms.new('Logical Disk', '.*', '.*', @mapping_path, @mock, @common)
    time = Time.parse('2015-10-21 16:21:19 -0700')
    result = omilib.enumerate(time)
    assert_equal(@OMS_result_logical_disk_all, result, "The result of enumerate differs from the expected result")
  end

  def test_connect
    # We should connect automatically on instance creation 
    OmiOms.new('Apache HTTP Server', 'inst_regex', 'counter_regex', @mapping_path, @mock)
    assert_equal(true, @mock.called_connect, "Connect was not called")
  end
  
  def test_disconnect
    omilib = OmiOms.new('Apache HTTP Server', 'inst_regex', 'counter_regex', @mapping_path, @mock)
    omilib.disconnect
    assert_equal(true, @mock.called_disconnect, "Disconnect was not called")
  end

  def test_enumerate_filtering_or_with_null_metrics
    @mock.omi_result = @OMI_result_logical_disk_null_metrics
    omilib = OmiOms.new('Logical Disk', '/', '%|Disk', @mapping_path, @mock, @common)

    time = Time.parse('2015-10-21 16:21:19 -0700')
    result = omilib.enumerate(time)
    assert_equal(@OMS_result_logical_disk_or_with_null_metrics, result, "The result of enumerate differs from the expected result")
    $log.clear
  end

  def set_static_mock_data
    # To keep the tests more readable, dump ugly data here
    @OMI_result_logical_disk = '[{"ClassName":"SCX_FileSystemStatisticalInformation","Caption":"File system information","Description":"Performance statistics related to a logical unit of secondary storage","Name":"/","IsAggregate":"false","IsOnline":"true","FreeMegabytes":"85293","UsedMegabytes":"13097","PercentFreeSpace":"87","PercentUsedSpace":"13","PercentFreeInodes":"95","PercentUsedInodes":"5","BytesPerSecond":"8792","ReadBytesPerSecond":"3713","WriteBytesPerSecond":"5079","TransfersPerSecond":"1","ReadsPerSecond":"0","WritesPerSecond":"1"},{"ClassName":"SCX_FileSystemStatisticalInformation","Caption":"File system information","Description":"Performance statistics related to a logical unit of secondary storage","Name":"/boot","IsAggregate":"false","IsOnline":"true","FreeMegabytes":"70","UsedMegabytes":"166","PercentFreeSpace":"30","PercentUsedSpace":"70","PercentFreeInodes":"99","PercentUsedInodes":"1","BytesPerSecond":"0","ReadBytesPerSecond":"0","WriteBytesPerSecond":"0","TransfersPerSecond":"0","ReadsPerSecond":"0","WritesPerSecond":"0"},{"ClassName":"SCX_FileSystemStatisticalInformation","Caption":"File system information","Description":"Performance statistics related to a logical unit of secondary storage","Name":"_Total","IsAggregate":"true","IsOnline":"true","FreeMegabytes":"85363","UsedMegabytes":"13263","PercentFreeSpace":"87","PercentUsedSpace":"13","PercentFreeInodes":"100","PercentUsedInodes":"0","BytesPerSecond":"8792","ReadBytesPerSecond":"3713","WriteBytesPerSecond":"5079","TransfersPerSecond":"1","ReadsPerSecond":"0","WritesPerSecond":"1"}]'
    
    @OMS_result_logical_disk_filter = {"DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement", "DataItems"=>[{"Timestamp"=>"2015-10-21T23:21:19.000Z", "Host"=>"MockHostname", "ObjectName"=>"Logical Disk", "InstanceName"=>"_Total", "Collections"=>[{"CounterName"=>"% Free Space", "Value"=>"87"}, {"CounterName"=>"% Used Space", "Value"=>"13"}, {"CounterName"=>"% Free Inodes", "Value"=>"100"}, {"CounterName"=>"% Used Inodes", "Value"=>"0"}]}]}

    @OMS_result_logical_disk_or = {"DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement", "DataItems"=>[{"Timestamp"=>"2015-10-21T23:21:19.000Z", "Host"=>"MockHostname", "ObjectName"=>"Logical Disk", "InstanceName"=>"/", "Collections"=>[{"CounterName"=>"% Free Space", "Value"=>"87"}, {"CounterName"=>"% Used Space", "Value"=>"13"}, {"CounterName"=>"% Free Inodes", "Value"=>"95"}, {"CounterName"=>"% Used Inodes", "Value"=>"5"}, {"CounterName"=>"Logical Disk Bytes/sec", "Value"=>"8792"}, {"CounterName"=>"Disk Read Bytes/sec", "Value"=>"3713"}, {"CounterName"=>"Disk Write Bytes/sec", "Value"=>"5079"}, {"CounterName"=>"Disk Transfers/sec", "Value"=>"1"}, {"CounterName"=>"Disk Reads/sec", "Value"=>"0"}, {"CounterName"=>"Disk Writes/sec", "Value"=>"1"}]}, {"Timestamp"=>"2015-10-21T23:21:19.000Z", "Host"=>"MockHostname", "ObjectName"=>"Logical Disk", "InstanceName"=>"/boot", "Collections"=>[{"CounterName"=>"% Free Space", "Value"=>"30"}, {"CounterName"=>"% Used Space", "Value"=>"70"}, {"CounterName"=>"% Free Inodes", "Value"=>"99"}, {"CounterName"=>"% Used Inodes", "Value"=>"1"}, {"CounterName"=>"Logical Disk Bytes/sec", "Value"=>"0"}, {"CounterName"=>"Disk Read Bytes/sec", "Value"=>"0"}, {"CounterName"=>"Disk Write Bytes/sec", "Value"=>"0"}, {"CounterName"=>"Disk Transfers/sec", "Value"=>"0"}, {"CounterName"=>"Disk Reads/sec", "Value"=>"0"}, {"CounterName"=>"Disk Writes/sec", "Value"=>"0"}]}]}
  
    @OMS_result_logical_disk_all = {"DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement", "DataItems"=>[{"Timestamp"=>"2015-10-21T23:21:19.000Z", "Host"=>"MockHostname", "ObjectName"=>"Logical Disk", "InstanceName"=>"/", "Collections"=>[{"CounterName"=>"Free Megabytes", "Value"=>"85293"}, {"CounterName"=>"% Free Space", "Value"=>"87"}, {"CounterName"=>"% Used Space", "Value"=>"13"}, {"CounterName"=>"% Free Inodes", "Value"=>"95"}, {"CounterName"=>"% Used Inodes", "Value"=>"5"}, {"CounterName"=>"Logical Disk Bytes/sec", "Value"=>"8792"}, {"CounterName"=>"Disk Read Bytes/sec", "Value"=>"3713"}, {"CounterName"=>"Disk Write Bytes/sec", "Value"=>"5079"}, {"CounterName"=>"Disk Transfers/sec", "Value"=>"1"}, {"CounterName"=>"Disk Reads/sec", "Value"=>"0"}, {"CounterName"=>"Disk Writes/sec", "Value"=>"1"}]}, {"Timestamp"=>"2015-10-21T23:21:19.000Z", "Host"=>"MockHostname", "ObjectName"=>"Logical Disk", "InstanceName"=>"/boot", "Collections"=>[{"CounterName"=>"Free Megabytes", "Value"=>"70"}, {"CounterName"=>"% Free Space", "Value"=>"30"}, {"CounterName"=>"% Used Space", "Value"=>"70"}, {"CounterName"=>"% Free Inodes", "Value"=>"99"}, {"CounterName"=>"% Used Inodes", "Value"=>"1"}, {"CounterName"=>"Logical Disk Bytes/sec", "Value"=>"0"}, {"CounterName"=>"Disk Read Bytes/sec", "Value"=>"0"}, {"CounterName"=>"Disk Write Bytes/sec", "Value"=>"0"}, {"CounterName"=>"Disk Transfers/sec", "Value"=>"0"}, {"CounterName"=>"Disk Reads/sec", "Value"=>"0"}, {"CounterName"=>"Disk Writes/sec", "Value"=>"0"}]}, {"Timestamp"=>"2015-10-21T23:21:19.000Z", "Host"=>"MockHostname", "ObjectName"=>"Logical Disk", "InstanceName"=>"_Total", "Collections"=>[{"CounterName"=>"Free Megabytes", "Value"=>"85363"}, {"CounterName"=>"% Free Space", "Value"=>"87"}, {"CounterName"=>"% Used Space", "Value"=>"13"}, {"CounterName"=>"% Free Inodes", "Value"=>"100"}, {"CounterName"=>"% Used Inodes", "Value"=>"0"}, {"CounterName"=>"Logical Disk Bytes/sec", "Value"=>"8792"}, {"CounterName"=>"Disk Read Bytes/sec", "Value"=>"3713"}, {"CounterName"=>"Disk Write Bytes/sec", "Value"=>"5079"}, {"CounterName"=>"Disk Transfers/sec", "Value"=>"1"}, {"CounterName"=>"Disk Reads/sec", "Value"=>"0"}, {"CounterName"=>"Disk Writes/sec", "Value"=>"1"}]}]}

    @OMI_result_logical_disk_null_metrics = '[{"ClassName":"SCX_FileSystemStatisticalInformation","Caption":"File system information","Description":"Performance statistics related to a logical unit of secondary storage","Name":"/","IsAggregate":"false","IsOnline":"true","FreeMegabytes":"85293","UsedMegabytes":"13097","PercentFreeSpace":"87","PercentUsedSpace":"13","PercentFreeInodes":"95","PercentUsedInodes":"5","BytesPerSecond":null,"ReadBytesPerSecond":"3713","WriteBytesPerSecond":"5079","TransfersPerSecond":"1","ReadsPerSecond":null,"WritesPerSecond":null},{"ClassName":"SCX_FileSystemStatisticalInformation","Caption":"File system information","Description":"Performance statistics related to a logical unit of secondary storage","Name":"/boot","IsAggregate":"false","IsOnline":"true","FreeMegabytes":"70","UsedMegabytes":"166","PercentFreeSpace":"30","PercentUsedSpace":"70","PercentFreeInodes":"99","PercentUsedInodes":"1","BytesPerSecond":"0","ReadBytesPerSecond":null,"WriteBytesPerSecond":null,"TransfersPerSecond":"0","ReadsPerSecond":"0","WritesPerSecond":"0"},{"ClassName":"SCX_FileSystemStatisticalInformation","Caption":"File system information","Description":"Performance statistics related to a logical unit of secondary storage","Name":"_Total","IsAggregate":"true","IsOnline":"true","FreeMegabytes":"85363","UsedMegabytes":"13263","PercentFreeSpace":"87","PercentUsedSpace":"13","PercentFreeInodes":"100","PercentUsedInodes":"0","BytesPerSecond":"8792","ReadBytesPerSecond":"3713","WriteBytesPerSecond":"5079","TransfersPerSecond":"1","ReadsPerSecond":null,"WritesPerSecond":null}]'

   @OMS_result_logical_disk_or_with_null_metrics = {"DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement", "DataItems"=>[{"Timestamp"=>"2015-10-21T23:21:19.000Z", "Host"=>"MockHostname", "ObjectName"=>"Logical Disk", "InstanceName"=>"/", "Collections"=>[{"CounterName"=>"% Free Space", "Value"=>"87"}, {"CounterName"=>"% Used Space", "Value"=>"13"}, {"CounterName"=>"% Free Inodes", "Value"=>"95"}, {"CounterName"=>"% Used Inodes", "Value"=>"5"}, {"CounterName"=>"Disk Read Bytes/sec", "Value"=>"3713"}, {"CounterName"=>"Disk Write Bytes/sec", "Value"=>"5079"}, {"CounterName"=>"Disk Transfers/sec", "Value"=>"1"}]}, {"Timestamp"=>"2015-10-21T23:21:19.000Z", "Host"=>"MockHostname", "ObjectName"=>"Logical Disk", "InstanceName"=>"/boot", "Collections"=>[{"CounterName"=>"% Free Space", "Value"=>"30"}, {"CounterName"=>"% Used Space", "Value"=>"70"}, {"CounterName"=>"% Free Inodes", "Value"=>"99"}, {"CounterName"=>"% Used Inodes", "Value"=>"1"}, {"CounterName"=>"Logical Disk Bytes/sec", "Value"=>"0"}, {"CounterName"=>"Disk Transfers/sec", "Value"=>"0"}, {"CounterName"=>"Disk Reads/sec", "Value"=>"0"}, {"CounterName"=>"Disk Writes/sec", "Value"=>"0"}]}]}

  end

end
