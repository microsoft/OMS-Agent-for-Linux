require_relative 'oms_omi_lib_test'
require_relative '../../../source/code/plugins/wlm_oms_omi_lib'

class In_WLM_OMS_OMI_Test < In_OMS_OMI_Test

  def setup
    @mock = MockOmiInterface.new
    @common = MockCommon
    @mapping_path = "#{ENV['BASE_DIR']}/installer/conf/wlm_monitor_mapping.json"
    set_expected_data
    set_static_mock_data
  end

  def test_get_specific_mapping_wlm
    wlm_object_names = ['Processor', 'Logical Disk', 'Memory', 'Physical Disk', 'Network Adapter', 'Apache HTTP Server Statistics',
                        'Apache HTTP Server', 'Apache Virtual Host', 'Apache Virtual Host Certificate']
    wlm_object_names.each { |name| validate_specific_mapping(name, @mapping_path) }
  end

  def test_get_cim_to_wlm_mappings
    omilib = WlmOmiOms.new('Processor', 'inst_regex', 'counter_regex', @mapping_path, @mock)
    
    cim_properties = [{
                        "CimPropertyName"=> "PercentProcessorTime",
                        "CounterName"=> "% Processor Time"
                      },
                      {
                        "CimPropertyName"=> "PercentDPCTime",
                        "CounterName"=> "% DPC Time"
                      },
                      {
                        "CimPropertyName"=> "PercentInterruptTime",
                        "CounterName"=> "% Interrupt Time"
                      }]
    
    cim_to_wlm = omilib.get_cim_to_oms_mappings(cim_properties)
    expected = {"PercentProcessorTime"=>"% Processor Time", "PercentDPCTime"=>"% DPC Time", "PercentInterruptTime"=>"% Interrupt Time"}
    assert_equal(expected, cim_to_wlm, "Did not generate the correct mapping of CIM to WLM properties")  
  end

  def test_enumerate_wlm_instances
    wlm_object_names = ['Processor', 'Logical Disk', 'Memory', 'Physical Disk', 'Network Adapter']
    wlm_object_names.each do |object_name| 
      @mock.omi_result = @mock_data[object_name]
      omilib = WlmOmiOms.new(object_name, '.*', '.*', @mapping_path, @mock, @common)
      time = Time.parse('2018-07-06 05:02:48 +0530')
      result = omilib.enumerate(time, "WLM_LINUX_PERF_BLOB", "InfrastructureInsights")
      assert_equal( @expected_enumerate[object_name] , result, "Did not generate the oms_instance properly for object #{object_name}")  
    end
  end 

  def set_expected_data
    @expected_enumerate = {}
    @expected_enumerate['Logical Disk'] = {"DataItems"=>[{"Collections"=>[{"CounterName"=>"Logical Disk Online","Value"=>"true"},{"CounterName"=>"% Free Space","Value"=>"31"},{"CounterName"=>"Free Megabytes","Value"=>"2050"},{"CounterName"=>"% Free Inodes","Value"=>"68"}],"Host"=>"MockHostname","InstanceName"=>"/","Logical Disk"=>"/","ObjectName"=>"Logical Disk","Timestamp"=>"2018-07-05T23:32:48.000Z"},{"Collections"=>[{"CounterName"=>"Logical Disk Online","Value"=>"true"},{"CounterName"=>"% Free Space","Value"=>"31"},{"CounterName"=>"Free Megabytes","Value"=>"2050"},{"CounterName"=>"% Free Inodes","Value"=>"68"}],"Host"=>"MockHostname","InstanceName"=>"/boot","Logical Disk"=>"/boot","ObjectName"=>"Logical Disk","Timestamp"=>"2018-07-05T23:32:48.000Z"},{"Collections"=>[{"CounterName"=>"Logical Disk Online","Value"=>"true"},{"CounterName"=>"% Free Space","Value"=>"31"},{"CounterName"=>"Free Megabytes","Value"=>"2050"},{"CounterName"=>"% Free Inodes","Value"=>"68"}],"Host"=>"MockHostname","InstanceName"=>"/mnt/resource","Logical Disk"=>"/mnt/resource","ObjectName"=>"Logical Disk","Timestamp"=>"2018-07-05T23:32:48.000Z"},{"Collections"=>[{"CounterName"=>"Logical Disk Online","Value"=>"true"},{"CounterName"=>"% Free Space","Value"=>"87"},{"CounterName"=>"Free Megabytes","Value"=>"85363"},{"CounterName"=>"% Free Inodes","Value"=>"100"}],"Host"=>"MockHostname","InstanceName"=>"_Total","Logical Disk"=>"_Total","ObjectName"=>"Logical Disk","Timestamp"=>"2018-07-05T23:32:48.000Z"}],"DataType"=>"WLM_LINUX_PERF_BLOB","IPName"=>"InfrastructureInsights"}
    @expected_enumerate['Processor'] = {"DataItems"=>[{"Collections"=>[{"CounterName"=>"% DPC Time","Value"=>"11"},{"CounterName"=>"% Processor Time","Value"=>"80"},{"CounterName"=>"% Interrupt Time","Value"=>"9"}],"Host"=>"MockHostname","InstanceName"=>"0","ObjectName"=>"Processor","Processor"=>"0","Timestamp"=>"2018-07-05T23:32:48.000Z"},{"Collections"=>[{"CounterName"=>"% DPC Time","Value"=>"11"},{"CounterName"=>"% Processor Time","Value"=>"80"},{"CounterName"=>"% Interrupt Time","Value"=>"9"}],"Host"=>"MockHostname","InstanceName"=>"1","ObjectName"=>"Processor","Processor"=>"1","Timestamp"=>"2018-07-05T23:32:48.000Z"},{"Collections"=>[{"CounterName"=>"% DPC Time","Value"=>"11"},{"CounterName"=>"% Processor Time","Value"=>"80"},{"CounterName"=>"% Interrupt Time","Value"=>"9"}],"Host"=>"MockHostname","InstanceName"=>"_Total","ObjectName"=>"Processor","Processor"=>"_Total","Timestamp"=>"2018-07-05T23:32:48.000Z"}],"DataType"=>"WLM_LINUX_PERF_BLOB","IPName"=>"InfrastructureInsights"}
    @expected_enumerate['Physical Disk'] = {"DataItems"=>[{"Collections"=>[{"CounterName"=>"Physical Disk Online","Value"=>"true"},{"CounterName"=>"Avg. Disk sec/Read","Value"=>"0.04"},{"CounterName"=>"Avg. Disk sec/Transfer","Value"=>"0.02"},{"CounterName"=>"Avg. Disk sec/Write","Value"=>"0.03"}],"Host"=>"MockHostname","InstanceName"=>"sda","ObjectName"=>"Physical Disk","Physical Disk"=>"sda","Timestamp"=>"2018-07-05T23:32:48.000Z"},{"Collections"=>[{"CounterName"=>"Physical Disk Online","Value"=>"true"},{"CounterName"=>"Avg. Disk sec/Read","Value"=>"0.04"},{"CounterName"=>"Avg. Disk sec/Transfer","Value"=>"0.02"},{"CounterName"=>"Avg. Disk sec/Write","Value"=>"0.03"}],"Host"=>"MockHostname","InstanceName"=>"sdb","ObjectName"=>"Physical Disk","Physical Disk"=>"sdb","Timestamp"=>"2018-07-05T23:32:48.000Z"},{"Collections"=>[{"CounterName"=>"Physical Disk Online","Value"=>"true"},{"CounterName"=>"Avg. Disk sec/Read","Value"=>"0"},{"CounterName"=>"Avg. Disk sec/Transfer","Value"=>"0.05"},{"CounterName"=>"Avg. Disk sec/Write","Value"=>"0"}],"Host"=>"MockHostname","InstanceName"=>"_Total","ObjectName"=>"Physical Disk","Physical Disk"=>"_Total","Timestamp"=>"2018-07-05T23:32:48.000Z"}],"DataType"=>"WLM_LINUX_PERF_BLOB","IPName"=>"InfrastructureInsights"} 
    @expected_enumerate['Network Adapter'] = {"DataItems"=>[{"Collections"=>[{"CounterName"=>"Enabled state","Value"=>"1"}],"Host"=>"MockHostname","InstanceName"=>"eth0","Network Adapter"=>"eth0","ObjectName"=>"Network Adapter","Timestamp"=>"2018-07-05T23:32:48.000Z"},{"Collections"=>[{"CounterName"=>"Enabled state","Value"=>"1"}],"Host"=>"MockHostname","InstanceName"=>"eth1","Network Adapter"=>"eth1","ObjectName"=>"Network Adapter","Timestamp"=>"2018-07-05T23:32:48.000Z"}],"DataType"=>"WLM_LINUX_PERF_BLOB","IPName"=>"InfrastructureInsights"} 
    @expected_enumerate['Memory'] = {"DataItems"=>[{"Collections"=>[{"CounterName"=>"Available MBytes Memory","Value"=>"2.5"},{"CounterName"=>"Available MBytes Swap","Value"=>"2.5"}],"Host"=>"MockHostname","InstanceName"=>"Memory","Memory"=>"Memory","ObjectName"=>"Memory","Timestamp"=>"2018-07-05T23:32:48.000Z"}],"DataType"=>"WLM_LINUX_PERF_BLOB","IPName"=>"InfrastructureInsights"}
  end 

  def set_static_mock_data
    @mock_data = {}
    @mock_data['Logical Disk'] = '[{"IsOnline":"true","IsAggregate":"false","Description":"Performance statistics related to a logical unit of secondary storage","TransfersPerSecond":"1","PercentFreeSpace":"31","FreeMegabytes":"2050","ReadsPerSecond":"0","ClassName":"SCX_FileSystemStatisticalInformation","Caption":"File system information","BytesPerSecond":"8792","ReadBytesPerSecond":"3713","PercentUsedSpace":"13","PercentUsedInodes":"5","WriteBytesPerSecond":"5079","UsedMegabytes":"13097","PercentFreeInodes":"68","WritesPerSecond":"1","Name":"/"},{"IsOnline":"true","IsAggregate":"false","Description":"Performance statistics related to a logical unit of secondary storage","TransfersPerSecond":"0","PercentFreeSpace":"31","FreeMegabytes":"2050","ReadsPerSecond":"0","ClassName":"SCX_FileSystemStatisticalInformation","Caption":"File system information","BytesPerSecond":"0","ReadBytesPerSecond":"0","PercentUsedSpace":"70","PercentUsedInodes":"1","WriteBytesPerSecond":"0","UsedMegabytes":"166","PercentFreeInodes":"68","WritesPerSecond":"0","Name":"/boot"},{"IsOnline":"true","IsAggregate":"false","Description":"Performance statistics related to a logical unit of secondary storage","TransfersPerSecond":"0","PercentFreeSpace":"31","FreeMegabytes":"2050","ReadsPerSecond":"0","ClassName":"SCX_FileSystemStatisticalInformation","Caption":"File system information","BytesPerSecond":"0","ReadBytesPerSecond":"0","PercentUsedSpace":"70","PercentUsedInodes":"1","WriteBytesPerSecond":"0","UsedMegabytes":"166","PercentFreeInodes":"68","WritesPerSecond":"0","Name":"/mnt/resource"},{"IsOnline":"true","IsAggregate":"true","Description":"Performance statistics related to a logical unit of secondary storage","TransfersPerSecond":"1","PercentFreeSpace":"87","FreeMegabytes":"85363","ReadsPerSecond":"0","ClassName":"SCX_FileSystemStatisticalInformation","Caption":"File system information","BytesPerSecond":"8792","ReadBytesPerSecond":"3713","PercentUsedSpace":"13","PercentUsedInodes":"0","WriteBytesPerSecond":"5079","UsedMegabytes":"13263","PercentFreeInodes":"100","WritesPerSecond":"1","Name":"_Total"}]'
    @mock_data['Processor'] = '[{"IsAggregate":"false","Description":"CPU usage statistics","PercentDPCTime":"11","PercentPrivilegedTime":"0","ClassName":"SCX_RTProcessorStatisticalInformation","Caption":"Processor information","PercentIOWaitTime":"0","PercentNiceTime":"0","PercentUserTime":"0","PercentProcessorTime":"80","PercentInterruptTime":"9","PercentIdleTime":"0","Name":"0"},{"IsAggregate":"false","Description":"CPU usage statistics","PercentDPCTime":"11","PercentPrivilegedTime":"0","ClassName":"SCX_RTProcessorStatisticalInformation","Caption":"Processor information","PercentIOWaitTime":"0","PercentNiceTime":"0","PercentUserTime":"0","PercentProcessorTime":"80","PercentInterruptTime":"9","PercentIdleTime":"0","Name":"1"},{"IsAggregate":"true","Description":"CPU usage statistics","PercentDPCTime":"11","PercentPrivilegedTime":"0","ClassName":"SCX_RTProcessorStatisticalInformation","Caption":"Processor information","PercentIOWaitTime":"0","PercentNiceTime":"0","PercentUserTime":"0","PercentProcessorTime":"80","PercentInterruptTime":"9","PercentIdleTime":"0","Name":"_Total"}]'
    @mock_data['Physical Disk'] = '[{"IsOnline":"true","IsAggregate":"false","Description":"Performance statistics related to a physical unit of secondary storage","TransfersPerSecond":"0","AverageReadTime":"0.04","BytesPerSecond":"0","ReadsPerSecond":"0","AverageTransferTime":"0.02","ClassName":"SCX_DiskDriveStatisticalInformation","Caption":"Disk drive information","ReadBytesPerSecond":"0","AverageWriteTime":"0.03","WriteBytesPerSecond":"0","AverageDiskQueueLength":"0","WritesPerSecond":"0","Name":"sda"},{"IsOnline":"true","IsAggregate":"false","Description":"Performance statistics related to a physical unit of secondary storage","TransfersPerSecond":"0","AverageReadTime":"0.04","BytesPerSecond":"0","ReadsPerSecond":"0","AverageTransferTime":"0.02","ClassName":"SCX_DiskDriveStatisticalInformation","Caption":"Disk drive information","ReadBytesPerSecond":"0","AverageWriteTime":"0.03","WriteBytesPerSecond":"0","AverageDiskQueueLength":"0","WritesPerSecond":"0","Name":"sdb"},{"IsOnline":"true","IsAggregate":"true","Description":"Performance statistics related to a physical unit of secondary storage","TransfersPerSecond":"0","AverageReadTime":"0","BytesPerSecond":"0","ReadsPerSecond":"0","AverageTransferTime":"0.05","ClassName":"SCX_DiskDriveStatisticalInformation","Caption":"Disk drive information","ReadBytesPerSecond":"0","AverageWriteTime":"0","WriteBytesPerSecond":"0","AverageDiskQueueLength":"0","WritesPerSecond":"0","Name":"_Total"}]' 
    @mock_data['Network Adapter'] = '[{"IPv4Address":"10.51.0.13","ElementName":"eth0","Description":"Properties of an IP protocol connection endpoint","EnabledState":"1","ClassName":"SCX_IPProtocolEndpoint","Caption":"IP protocol endpoint information","SystemName":"wlioredhat73","CreationClassName":"SCX_IPProtocolEndpoint","SubnetMask":"255.255.252.0","IPv4BroadcastAddress":"10.51.0.255","SystemCreationClassName":"SCX_ComputerSystem","Name":"eth0"},{"IPv4Address":"192.168.122.1","ElementName":"eth1","Description":"Properties of an IP protocol connection endpoint","EnabledState":"1","ClassName":"SCX_IPProtocolEndpoint","Caption":"IP protocol endpoint information","SystemName":"wlioredhat73","CreationClassName":"SCX_IPProtocolEndpoint","SubnetMask":"255.255.255.0","IPv4BroadcastAddress":"192.168.122.255","SystemCreationClassName":"SCX_ComputerSystem","Name":"eth1"}]'
    @mock_data['Memory'] = '[{"ClassName":"SCX_MemoryStatisticalInformation","IsAggregate":"true","PercentAvailableMemory":"90","Description":"Memory usage and performance statistics","PercentUsedByCache":"0","PercentUsedSwap":"0","PagesPerSec":"0","UsedMemory":"498","Caption":"Memory information","UsedSwap":"9","AvailableMemory":"2.5","AvailableSwap":"2.5","PercentAvailableSwap":"100","Name":"Memory","PercentUsedMemory":"36","PagesReadPerSec":"0","PagesWrittenPerSec":"0"}]'
  end 
end #class