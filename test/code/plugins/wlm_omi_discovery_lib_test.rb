require 'test/unit'
require_relative '../../../source/code/plugins/wlm_omi_discovery_lib'
require_relative 'omstestlib'

class In_OMS_WLM_Test < Test::Unit::TestCase
  
  class MockOmiWlmInterface
    attr_accessor :omi_result
    attr_reader :called_connect
    attr_reader :called_disconnect

    def initialize
      @called_connect = false
      @called_disconnect = false
    end
    
    def enumerate(items)
      return @omi_result[items[0][1]]
    end

    def connect
      @called_connect = true
    end

    def disconnect
      @called_disconnect = true
    end
    
  end # class MockOmiWlmInterface
  
  def setup
    $log = OMS::MockLog.new
    @mock = MockOmiWlmInterface.new
    set_static_mock_data
    @mapping_path = "#{ENV['BASE_DIR']}/installer/conf/wlm_discovery_mapping.json"
  end

  def teardown
  end

  def test_wlm_omi_data
    omilib = WLM::WLMOMIDiscoveryCollector.new(@mapping_path, @mock)
    discovery_data = omilib.get_discovery_data()
    assert_equal(discovery_data, @expected_result, "Discovery data not as expected")
  end  

  def set_static_mock_data
    @mock.omi_result = {}
    @mock.omi_result['SCX_OperatingSystem'] = '[{"ClassName":"SCX_OperatingSystem","Caption":"Ubuntu 16.04 (x86_64)","Description":"Ubuntu 16.04 (x86_64)","Name":"Linux Distribution","EnabledState":"5","RequestedState":"12","EnabledDefault":"2","CSCreationClassName":"SCX_ComputerSystem","CSName":"vimish-ubu-01.scx.com","CreationClassName":"SCX_OperatingSystem","OSType":"36","OtherTypeDescription":"4.4.0-96-generic #119-Ubuntu SMP Tue Sep 12 14:59:54 UTC 2017 x86_64   ","Version":"16.04","LastBootUpTime":{"MI_Type":"MI_Timestamp","year":"2017","month":"10","day":"14","hour":"8","minute":"21","second":"26","microseconds":"0","utc":"0"},"LocalDateTime":{"MI_Type":"MI_Timestamp","year":"2017","month":"10","day":"17","hour":"3","minute":"58","second":"26","microseconds":"25506","utc":"0"},"CurrentTimeZone":"-420","NumberOfLicensedUsers":"0","NumberOfUsers":"1","NumberOfProcesses":"118","MaxNumberOfProcesses":"3520","TotalSwapSpaceSize":"1044476","TotalVirtualMemorySize":"1535404","FreeVirtualMemory":"1219404","FreePhysicalMemory":"198736","TotalVisibleMemorySize":"490928","SizeStoredInPagingFiles":"1044476","FreeSpaceInPagingFiles":"1020668","MaxProcessMemorySize":"0","MaxProcessesPerUser":"1760","OperatingSystemCapability":"64 bit","SystemUpTime":"243034"}]'
    
    @mock.omi_result['SCX_RTProcessorStatisticalInformation'] = '[{"ClassName":"SCX_RTProcessorStatisticalInformation","Caption":"Processor information","Description":"CPU usage statistics","Name":"0","IsAggregate":"false","PercentIdleTime":"99","PercentUserTime":"0","PercentNiceTime":"0","PercentPrivilegedTime":"0","PercentInterruptTime":"0","PercentDPCTime":"0","PercentProcessorTime":"1","PercentIOWaitTime":"0"},{"ClassName":"SCX_RTProcessorStatisticalInformation","Caption":"Processor information","Description":"CPU usage statistics","Name":"_Total","IsAggregate":"true","PercentIdleTime":"99","PercentUserTime":"0","PercentNiceTime":"0","PercentPrivilegedTime":"0","PercentInterruptTime":"0","PercentDPCTime":"0","PercentProcessorTime":"1","PercentIOWaitTime":"0"}]'

    @mock.omi_result['SCX_FileSystem'] = ' [{"ClassName":"SCX_FileSystem","Caption":"File system information","Description":"Information about a logical unit of secondary storage","Name":"\/","CSCreationClassName":"SCX_ComputerSystem","CSName":"vimish-ubu-01.scx.com","CreationClassName":"SCX_FileSystem","Root":"\/","BlockSize":"4096","FileSystemSize":"132476702720","AvailableSpace":"124229484544","ReadOnly":"false","EncryptionMethod":"Not Encrypted","CompressionMethod":"Not Compressed","CaseSensitive":"true","CasePreserved":"true","MaxFileNameLength":"255","FileSystemType":"ext4","PersistenceType":"2","NumberOfFiles":"420291","IsOnline":"true","TotalInodes":"8224768","FreeInodes":"7804477"},{"ClassName":"SCX_FileSystem","Caption":"File system information","Description":"Information about a logical unit of secondary storage","Name":"\/boot","CSCreationClassName":"SCX_ComputerSystem","CSName":"vimish-ubu-01.scx.com","CreationClassName":"SCX_FileSystem","Root":"\/boot","BlockSize":"1024","FileSystemSize":"494512128","AvailableSpace":"18881536","ReadOnly":"false","EncryptionMethod":"Not Encrypted","CompressionMethod":"Not Compressed","CaseSensitive":"true","CasePreserved":"true","MaxFileNameLength":"255","FileSystemType":"ext2","PersistenceType":"2","NumberOfFiles":"347","IsOnline":"true","TotalInodes":"124928","FreeInodes":"124581"}]'
  
    @mock.omi_result['SCX_IPProtocolEndpoint'] = '[{"ClassName":"SCX_IPProtocolEndpoint","Caption":"IP protocol endpoint information","Description":"Properties of an IP protocol connection endpoint","ElementName":"eth0","Name":"eth0","EnabledState":"2","SystemCreationClassName":"SCX_ComputerSystem","SystemName":"vimish-ubu-01.scx.com","CreationClassName":"SCX_IPProtocolEndpoint","IPv4Address":"10.217.247.100","SubnetMask":"255.255.254.0","IPv4BroadcastAddress":"10.217.247.255"}]'

    @mock.omi_result['SCX_DiskDrive'] = '[{"ClassName":"SCX_DiskDrive","Caption":"Disk drive information","Description":"Information pertaining to a physical unit of secondary storage","Name":"sda","SystemCreationClassName":"SCX_ComputerSystem","SystemName":"vimish-ubu-01.scx.com","CreationClassName":"SCX_DiskDrive","DeviceID":"sda","MaxMediaSize":"136365211648","InterfaceType":"SCSI","Manufacturer":"Msft","Model":"Virtual Disk","TotalCylinders":"16578","TotalHeads":"255","TotalSectors":"266338304"}]'

  @expected_result =[{"class_name"=>"Universal Linux Computer","discovery_data"=>[{"CSName"=>"vimish-ubu-01.scx.com","CurrentTimeZone"=>"-420"}],"discovery_id"=>"SystemDiscoveryID"},{"class_name"=>"Processor","discovery_data"=>[{"Name"=>"0"}],"discovery_id"=>"ProcessorDiscoveryID","parent"=>"Universal Linux Computer"},{"class_name"=>"Logical Disk","discovery_data"=>[{"CompressionMethod"=>"Not Compressed","FileSystemSize"=>"132476702720","FileSystemType"=>"ext4","Name"=>"/"},{"CompressionMethod"=>"Not Compressed","FileSystemSize"=>"494512128","FileSystemType"=>"ext2","Name"=>"/boot"}],"discovery_id"=>"LogicalDiskDiscoveryID","parent"=>"Universal Linux Computer"},{"class_name"=>"Network Adapter","discovery_data"=>[{"ElementName"=>"eth0","IPv4Address"=>"10.217.247.100","Name"=>"eth0","SubnetMask"=>"255.255.254.0"}],"discovery_id"=>"NetworkAdapterDiscoveryID","parent"=>"Universal Linux Computer"},{"class_name"=>"Universal Linux Operating System","discovery_data"=>[{"Caption"=>"Ubuntu 16.04 (x86_64)","Version"=>"16.04"}],"discovery_id"=>"OperatingSystemDiscoveryID","parent"=>"Universal Linux Computer"},{"class_name"=>"Physical Disk","discovery_data"=>[{"InterfaceType"=>"SCSI","MaxMediaSize"=>"136365211648","Name"=>"sda","TotalCylinders"=>"16578","TotalHeads"=>"255","TotalSectors"=>"266338304"}],"discovery_id"=>"PhysicalDiskDiscoveryID","parent"=>"Universal Linux Computer"}]

  end
  
end # end In_OMS_WLM_Test
