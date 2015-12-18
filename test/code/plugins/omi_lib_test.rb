require 'test/unit'
require_relative '../../../source/code/plugins/omi_lib'

class TestRuntimeError2 < OmiModule::LoggingBase
	def log_error(text)
		raise text
	end
end

class OmiLib_Test < Test::Unit::TestCase
	class << self
		def startup
			@@omi_lib = OmiModule::Omi.new(TestRuntimeError2.new, ENV['BASE_DIR']+"/installer/conf/omi_mapping.json")
		end
 
		def shutdown
			#no op
		end
	end
	
	def test_transform_null_empty_record_returns_empty
		assert_equal({}, @@omi_lib.transform(nil, "default counters", "test host", Time.now), "null record fails")
		assert_equal({}, @@omi_lib.transform("", "default counters", "test host", Time.now), "empty record fails")
	end

	def test_transform_class_doesnt_exist_returns_empty
		# input record with class name that doesn't exist in the mapping
		input_nonexistent_class = [
			{
				"ClassName"=>"Undefined Class Name",
				"Caption"=>"File system information",
				"Description"=>"Performance statistics related to a logical unit of secondary storage",
				"Name"=>"/",
				"IsAggregate"=>"false",
				"IsOnline"=>"true",
				"FreeMegabytes"=>"87400",
				"UsedMegabytes"=>"10991",
				"PercentFreeSpace"=>"89",
				"PercentUsedSpace"=>"11",
				"PercentFreeInodes"=>"96",
				"PercentUsedInodes"=>"4",
				"BytesPerSecond"=>"0",
				"ReadBytesPerSecond"=>"0",
				"WriteBytesPerSecond"=>"0",
				"TransfersPerSecond"=>"0",
				"ReadsPerSecond"=>"0",
				"WritesPerSecond"=>"0"
			}
		]
		
		exception = assert_raise(RuntimeError) {@@omi_lib.transform(input_nonexistent_class.to_json, "default counters", "testhost", Time.now)}
		assert_equal("Class name not found in mappings", exception.message)
	end
	
	# helper method to call transform and validate output
	def transform_validate_records_helper(expected_output, input, selected_counters, error_msg)
		# strip Timestamp key from Transformed record
		transformed_processor_records = @@omi_lib.transform(input.to_json, selected_counters, "testhost", Time.now)
		transformed_processor_records.each do |trans_record|
			trans_record.tap{|x| x.delete("Timestamp")}
		end

		assert_equal(expected_output.to_json, transformed_processor_records.to_json, error_msg)
	end
	
	def test_transform_class_returns_valid_record_all_counters
		all_performance_counters = [
			"Processor % Processor Time",
			"Processor % Idle Time",
			"Processor % User Time",
			"Processor % Nice Time",
			"Processor % Privileged Time",
			"Processor % IO Wait Time",
			"Processor % Interrupt Time",
			"Processor % DPC Time",
			"Memory Available MBytes Memory",
			"Memory % Available Memory",
			"Memory Used Memory MBytes",
			"Memory % Used Memory",
			"Memory Pages/sec",
			"Memory Page Reads/sec",
			"Memory Page Writes/sec",
			"Memory Available MBytes Swap",
			"Memory % Available Swap Space",
			"Memory Used MBytes Swap Space",
			"Memory % Used Swap Space",
			"Logical Disk % Free Inodes",
			"Logical Disk % Used Inodes",
			"Logical Disk Free Megabytes",
			"Logical Disk % Free Space",
			"Logical Disk % Used Space",
			"Logical Disk Logical Disk Bytes/sec",
			"Logical Disk Disk Read Bytes/sec",
			"Logical Disk Disk Write Bytes/sec",
			"Logical Disk Disk Transfers/sec",
			"Logical Disk Disk Reads/sec",
			"Logical Disk Disk Writes/sec",
			"Physical Disk Physical Disk Bytes/sec",
			"Physical Disk Avg. Disk sec/Transfer",
			"Physical Disk Avg. Disk sec/Read",
			"Physical Disk Avg. Disk sec/Write",
			"Container Processor Usage sec",
			"Container % Processor Time",
			"Container Memory Usage MB",
			"Container Network Receive Bytes",
			"Container Network Send Bytes",
			"Container Disk Reads MB",
			"Container Disk Writes MB",
			"System Processes",
			"System Users",
			"System Free Virtual Memory",
			"System Free Physical Memory",
			"System Size Stored In Paging Files",
			"System Free Space in Paging Files",
			"System Uptime",
			"Process Pct Privileged Time",
			"Process Pct User Time",
			"Process Used Memory",
			"Process Virtual Shared Memory",
			"Apache HTTP Server Total Pct CPU",
			"Apache HTTP Server Idle Workers",
			"Apache HTTP Server Busy Workers",
			"Apache HTTP Server Pct Busy Workers",
			"Apache Virtual Host Requests per Second",
			"Apache Virtual Host KB per Request",
			"Apache Virtual Host Requests KB per Second",
			"Apache Virtual Host Errors per Minute - Client",
			"Apache Virtual Host Errors per Minute - Server",
			"MySQL Database Tables",
			"MySQL Database Disk Space in Bytes",
			"MySQL Server Key Cache Hit Pct",
			"MySQL Server Key Cache Write Pct",
			"MySQL Server Key Cache Use Pct",
			"MySQL Server Query Cache Hit Pct",
			"MySQL Server Cache Prunes Pct",
			"MySQL Server Query Cache Use Pct",
			"MySQL Server Table Cache Hit Pct",
			"MySQL Server Table Lock Contention Pct",
			"MySQL Server Table Cache Use Pct",
			"MySQL Server InnoDB Buffer Pool Hit Pct",
			"MySQL Server InnoDB Buffer Pool Use Pct",
			"MySQL Server Full Table Scan Pct",
			"MySQL Server InnoDB Buffer Pool Use Pct",
			"MySQL Server Disk Space Use in Bytes",
			"MySQL Server Connection Use Pct",
			"MySQL Server Aborted Connection Pct"
		]
	
		# Test SCX_RTProcessorStatisticalInformation
		processor_input_record = [{"ClassName"=>"SCX_RTProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"0","IsAggregate"=>"false","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"},{"ClassName"=>"SCX_RTProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"_Total","IsAggregate"=>"true","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"}]
		expected_processor_record = [{"Host":"testhost","ObjectName":"Processor","InstanceName":"0","Collections":[{"CounterName":"% Processor Time","Value":"0"},{"CounterName":"% Idle Time","Value":"0"},{"CounterName":"% User Time","Value":"0"},{"CounterName":"% Nice Time","Value":"0"},{"CounterName":"% Privileged Time","Value":"0"},{"CounterName":"% IO Wait Time","Value":"0"},{"CounterName":"% Interrupt Time","Value":"0"},{"CounterName":"% DPC Time","Value":"0"}]},{"Host":"testhost","ObjectName":"Processor","InstanceName":"_Total","Collections":[{"CounterName":"% Processor Time","Value":"0"},{"CounterName":"% Idle Time","Value":"0"},{"CounterName":"% User Time","Value":"0"},{"CounterName":"% Nice Time","Value":"0"},{"CounterName":"% Privileged Time","Value":"0"},{"CounterName":"% IO Wait Time","Value":"0"},{"CounterName":"% Interrupt Time","Value":"0"},{"CounterName":"% DPC Time","Value":"0"}]}]
		transform_validate_records_helper(expected_processor_record, processor_input_record, all_performance_counters, "Processor Input Class Failed!")
		
		# Test SCX_MemoryStatiscalInformation
		memory_input_record = [{"ClassName"=>"SCX_MemoryStatisticalInformation","Caption"=>"Memory information","Description"=>"Memory usage and performance statistics","Name"=>"Memory","IsAggregate"=>"true","AvailableMemory"=>"269","PercentAvailableMemory"=>"23","UsedMemory"=>"904","PercentUsedMemory"=>"77","PercentUsedByCache"=>"0","PagesPerSec"=>"0","PagesReadPerSec"=>"0","PagesWrittenPerSec"=>"0","AvailableSwap"=>"1987","PercentAvailableSwap"=>"97","UsedSwap"=>"56","PercentUsedSwap"=>"3"}]
		expected_memory_record = [{"Host":"testhost","ObjectName":"Memory","InstanceName":"Memory","Collections":[{"CounterName":"Available MBytes Memory","Value":"269"},{"CounterName":"% Available Memory","Value":"23"},{"CounterName":"Used Memory MBytes","Value":"904"},{"CounterName":"% Used Memory","Value":"77"},{"CounterName":"Pages/sec","Value":"0"},{"CounterName":"Page Reads/sec","Value":"0"},{"CounterName":"Page Writes/sec","Value":"0"},{"CounterName":"Available MBytes Swap","Value":"1987"},{"CounterName":"% Available Swap Space","Value":"97"},{"CounterName":"Used MBytes Swap Space","Value":"56"},{"CounterName":"% Used Swap Space","Value":"3"}]}]
		transform_validate_records_helper(expected_memory_record, memory_input_record, all_performance_counters, "Memory Input Class Failed!")
		
		# Test SCX_FileSystemStatisticalInformation
		file_input_record = [{"ClassName"=>"SCX_FileSystemStatisticalInformation","Caption"=>"File system information","Description"=>"Performance statistics related to a logical unit of secondary storage","Name"=>"/","IsAggregate"=>"false","IsOnline"=>"true","FreeMegabytes"=>"87400","UsedMegabytes"=>"10991","PercentFreeSpace"=>"89","PercentUsedSpace"=>"11","PercentFreeInodes"=>"96","PercentUsedInodes"=>"4","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0"},{"ClassName"=>"SCX_FileSystemStatisticalInformation","Caption"=>"File system information","Description"=>"Performance statistics related to a logical unit of secondary storage","Name"=>"/boot","IsAggregate"=>"false","IsOnline"=>"true","FreeMegabytes"=>"99","UsedMegabytes"=>"137","PercentFreeSpace"=>"42","PercentUsedSpace"=>"58","PercentFreeInodes"=>"99","PercentUsedInodes"=>"1","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0"},{"ClassName"=>"SCX_FileSystemStatisticalInformation","Caption"=>"File system information","Description"=>"Performance statistics related to a logical unit of secondary storage","Name"=>"_Total","IsAggregate"=>"true","IsOnline"=>"true","FreeMegabytes"=>"87499","UsedMegabytes"=>"11128","PercentFreeSpace"=>"89","PercentUsedSpace"=>"11","PercentFreeInodes"=>"100","PercentUsedInodes"=>"0","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0"}]
		expected_file_record = [{"Host":"testhost","ObjectName":"Logical Disk","InstanceName":"/","Collections":[{"CounterName":"% Free Inodes","Value":"96"},{"CounterName":"% Used Inodes","Value":"4"},{"CounterName":"Free Megabytes","Value":"87400"},{"CounterName":"% Free Space","Value":"89"},{"CounterName":"% Used Space","Value":"11"},{"CounterName":"Logical Disk Bytes/sec","Value":"0"},{"CounterName":"Disk Read Bytes/sec","Value":"0"},{"CounterName":"Disk Write Bytes/sec","Value":"0"},{"CounterName":"Disk Transfers/sec","Value":"0"},{"CounterName":"Disk Reads/sec","Value":"0"},{"CounterName":"Disk Writes/sec","Value":"0"}]},{"Host":"testhost","ObjectName":"Logical Disk","InstanceName":"/boot","Collections":[{"CounterName":"% Free Inodes","Value":"99"},{"CounterName":"% Used Inodes","Value":"1"},{"CounterName":"Free Megabytes","Value":"99"},{"CounterName":"% Free Space","Value":"42"},{"CounterName":"% Used Space","Value":"58"},{"CounterName":"Logical Disk Bytes/sec","Value":"0"},{"CounterName":"Disk Read Bytes/sec","Value":"0"},{"CounterName":"Disk Write Bytes/sec","Value":"0"},{"CounterName":"Disk Transfers/sec","Value":"0"},{"CounterName":"Disk Reads/sec","Value":"0"},{"CounterName":"Disk Writes/sec","Value":"0"}]},{"Host":"testhost","ObjectName":"Logical Disk","InstanceName":"_Total","Collections":[{"CounterName":"% Free Inodes","Value":"100"},{"CounterName":"% Used Inodes","Value":"0"},{"CounterName":"Free Megabytes","Value":"87499"},{"CounterName":"% Free Space","Value":"89"},{"CounterName":"% Used Space","Value":"11"},{"CounterName":"Logical Disk Bytes/sec","Value":"0"},{"CounterName":"Disk Read Bytes/sec","Value":"0"},{"CounterName":"Disk Write Bytes/sec","Value":"0"},{"CounterName":"Disk Transfers/sec","Value":"0"},{"CounterName":"Disk Reads/sec","Value":"0"},{"CounterName":"Disk Writes/sec","Value":"0"}]}]
		transform_validate_records_helper(expected_file_record, file_input_record, all_performance_counters, "File Input Class Failed!")
		
		# Test SCX_DiskDriveStatiscalInformation
		disk_input_record = [{"ClassName"=>"SCX_DiskDriveStatisticalInformation","Caption"=>"Disk drive information","Description"=>"Performance statistics related to a physical unit of secondary storage","Name"=>"sda","IsAggregate"=>"false","IsOnline"=>"true","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0","AverageReadTime"=>"0","AverageWriteTime"=>"0","AverageTransferTime"=>"0","AverageDiskQueueLength"=>"0"},{"ClassName"=>"SCX_DiskDriveStatisticalInformation","Caption"=>"Disk drive information","Description"=>"Performance statistics related to a physical unit of secondary storage","Name"=>"_Total","IsAggregate"=>"true","IsOnline"=>"true","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0","AverageReadTime"=>"0","AverageWriteTime"=>"0","AverageTransferTime"=>"0","AverageDiskQueueLength"=>"0"}]
		expected_disk_record = [{"Host":"testhost","ObjectName":"Physical Disk","InstanceName":"sda","Collections":[{"CounterName":"Physical Disk Bytes/sec","Value":"0"},{"CounterName":"Avg. Disk sec/Transfer","Value":"0"},{"CounterName":"Avg. Disk sec/Read","Value":"0"},{"CounterName":"Avg. Disk sec/Write","Value":"0"}]},{"Host":"testhost","ObjectName":"Physical Disk","InstanceName":"_Total","Collections":[{"CounterName":"Physical Disk Bytes/sec","Value":"0"},{"CounterName":"Avg. Disk sec/Transfer","Value":"0"},{"CounterName":"Avg. Disk sec/Read","Value":"0"},{"CounterName":"Avg. Disk sec/Write","Value":"0"}]}]
		transform_validate_records_helper(expected_disk_record, disk_input_record, all_performance_counters, "Disk Input Class Failed!")
		
		# Test Container_ContainerStatistics
		container_perf_record = [{"ClassName"=>"Container_ContainerStatistics","InstanceID"=>"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","ElementName"=>"hello","CPUTotal"=>"5","CPUTotalPct"=>"1","MemUsedMB"=>"64","NetRXBytes"=>"256","NetTXBytes"=>"256","DiskBytesRead"=>"10","DiskBytesWritten"=>"2"}]
		expected_container_record = [{"Host":"testhost","ObjectName":"Container","InstanceName":"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","Collections":[{"CounterName":"Processor Usage sec","Value":"5"},{"CounterName":"% Processor Time","Value":"1"},{"CounterName":"Memory Usage MB","Value":"64"},{"CounterName":"Network Receive Bytes","Value":"256"},{"CounterName":"Network Send Bytes","Value":"256"},{"CounterName":"Disk Reads MB","Value":"10"},{"CounterName":"Disk Writes MB","Value":"2"}]}]
		transform_validate_records_helper(expected_container_record, container_perf_record, all_performance_counters, "Container Input Class Failed!")

		# Test SCX_OperatingSystem
		operatingsystem_perf_record = [{"ClassName"=>"SCX_OperatingSystem","Caption"=>"CentOS Linux 7.0 (x86_64)","Description"=>"CentOS Linux 7.0 (x86_64)","Name"=>"Linux Distribution","EnabledState"=>"5","RequestedState"=>"12","EnabledDefault"=>"2","CSCreationClassName"=>"SCX_ComputerSystem","CSName"=>"kab-cen-oms1.scx.com","CreationClassName"=>"SCX_OperatingSystem","OSType"=>"36","OtherTypeDescription"=>"3.10.0-123.el7.x86_64 #1 SMP Mon Jun 30 12:09:22 UTC 2014 x86_64","Version"=>"7.0","LastBootUpTime"=>"20151004103518.000000+000","LocalDateTime"=>"20151013132103.687815+000","CurrentTimeZone"=>"-420","NumberOfLicensedUsers"=>"0","NumberOfUsers"=>"1","NumberOfProcesses"=>"251","MaxNumberOfProcesses"=>"15515","TotalSwapSpaceSize"=>"1048572","TotalVirtualMemorySize"=>"2059520","FreeVirtualMemory"=>"1787396","FreePhysicalMemory"=>"738824","TotalVisibleMemorySize"=>"1010948","SizeStoredInPagingFiles"=>"1048572","FreeSpaceInPagingFiles"=>"1048572","MaxProcessMemorySize"=>"0","MaxProcessesPerUser"=>"7757","OperatingSystemCapability"=>"64 bit","SystemUpTime"=>"762352"		}]
		expected_operatingsystem_record = [{"Host":"testhost", "ObjectName":"System","InstanceName":"CentOS Linux 7.0 (x86_64)","Collections":[{"CounterName":"Processes","Value":"251"},{"CounterName":"Users","Value":"1"},{"CounterName":"Free Virtual Memory","Value":"1787396"},{"CounterName":"Free Physical Memory","Value":"738824"},{"CounterName":"Size Stored In Paging Files","Value":"1048572"},{"CounterName":"Free Space in Paging Files","Value":"1048572"},{"CounterName":"Uptime","Value":"762352"}]}]
		transform_validate_records_helper(expected_operatingsystem_record, operatingsystem_perf_record , all_performance_counters, "OperatingSystem Input Class Failed!")

		#Test SCX_UnixProcessStatisticalInformation
		process_perf_record = [{"ClassName"=>"SCX_UnixProcessStatisticalInformation","Caption"=>"Unix process information","Description"=>"A snapshot of a current process","Name"=>"omsagent","CSCreationClassName"=>"SCX_ComputerSystem","CSName"=>"kab-cen-oms1.scx.com","OSCreationClassName"=>"SCX_OperatingSystem","OSName"=>"Linux Distribution","Handle"=>"28402","ProcessCreationClassName"=>"SCX_UnixProcessStatisticalInformation","CPUTime"=>"0","VirtualText"=>"2666496","VirtualData"=>"953671680","VirtualSharedMemory"=>"5216","CpuTimeDeadChildren"=>"180","SystemTimeDeadChildren"=>"123","PercentUserTime"=>"0","PercentPrivilegedTime"=>"0","UsedMemory"=>"40208","PercentUsedMemory"=>"3","PagesReadPerSec"=>"0"}]
		expected_process_record = [{"Host":"testhost", "ObjectName":"Process","InstanceName":"omsagent","Collections":[{"CounterName":"Pct User Time","Value":"0"},{"CounterName":"Pct Privileged Time","Value":"0"},{"CounterName":"Used Memory","Value":"40208"},{"CounterName":"Virtual Shared Memory","Value":"5216"}]}]
		transform_validate_records_helper(expected_process_record, process_perf_record , all_performance_counters, "Process Input Class Failed!")

		#Test Apache_HTTPDServerStatistics
		apacheserver_perf_record = [{"ClassName"=>"Apache_HTTPDServerStatistics","InstanceID"=>"/etc/httpd/conf/httpd.conf","TotalPctCPU"=>"0","IdleWorkers"=>"0","BusyWorkers"=>"0","PctBusyWorkers"=>"0","ConfigurationFile"=>"/etc/httpd/conf/httpd.conf"}]
		expected_apacheserver_record = [{"Host":"testhost", "ObjectName":"Apache HTTP Server","InstanceName":"/etc/httpd/conf/httpd.conf","Collections":[{"CounterName":"Total Pct CPU","Value":"0"},{"CounterName":"Idle Workers","Value":"0"},{"CounterName":"Busy Workers","Value":"0"},{"CounterName":"Pct Busy Workers","Value":"0"}]}]
		transform_validate_records_helper(expected_apacheserver_record, apacheserver_perf_record , all_performance_counters, "Apache Server Input Class Failed!")

  		#Test Apache_HTTPDVirtualHostStatistics
		apachevhost_perf_record = [{"ClassName"=>"Apache_HTTPDVirtualHostStatistics","InstanceID"=>"10.184.145.57,_default_:0","ServerName"=>"10.184.145.57","RequestsTotal"=>"0","RequestsTotalBytes"=>"0","RequestsPerSecond"=>"0","KBPerRequest"=>"0","KBPerSecond"=>"0","ErrorCount400"=>"0","ErrorCount500"=>"0","ErrorsPerMinute400"=>"0","ErrorsPerMinute500"=>"0"},{"ClassName"=>"Apache_HTTPDVirtualHostStatistics","InstanceID"=>"_Total","ServerName"=>"_Total","RequestsTotal"=>"0","RequestsTotalBytes"=>"0","RequestsPerSecond"=>"0","KBPerRequest"=>"0","KBPerSecond"=>"0","ErrorCount400"=>"0","ErrorCount500"=>"0","ErrorsPerMinute400"=>"0","ErrorsPerMinute500"=>"0"}]
		expected_apachevhost_record = [{"Host":"testhost","ObjectName":"Apache Virtual Host","InstanceName":"10.184.145.57,_default_:0","Collections":[{"CounterName":"Requests per Second","Value":"0"},{"CounterName":"KB per Request","Value":"0"},{"CounterName":"Requests KB per Second","Value":"0"},{"CounterName":"Errors per Minute - Client","Value":"0"},{"CounterName":"Errors per Minute - Server","Value":"0"}]},{"Host":"testhost","ObjectName":"Apache Virtual Host","InstanceName":"_Total","Collections":[{"CounterName":"Requests per Second","Value":"0"},{"CounterName":"KB per Request","Value":"0"},{"CounterName":"Requests KB per Second","Value":"0"},{"CounterName":"Errors per Minute - Client","Value":"0"},{"CounterName":"Errors per Minute - Server","Value":"0"}]}]
		transform_validate_records_helper(expected_apachevhost_record, apachevhost_perf_record , all_performance_counters, "Apache VHost Input Class Failed!")

   		#Test MySQL_Server_Database
		mysqldb_perf_record = [{"ClassName"=>"MySQL_Server_Database","InstanceID"=>"kab-cen-oms1:127.0.0.1:3306:information_schema","DatabaseName"=>"information_schema","NumberOfTables"=>"62","DiskSpaceInBytes"=>"147456"},{"ClassName"=>"MySQL_Server_Database","InstanceID"=>"kab-cen-oms1:127.0.0.1:3306:mysql","DatabaseName"=>"mysql","NumberOfTables"=>"24","DiskSpaceInBytes"=>"656438"}]
		expected_mysqldb_record = [{"Host":"testhost","ObjectName":"MySQL Database","InstanceName":"kab-cen-oms1:127.0.0.1:3306:information_schema","Collections":[{"CounterName":"Tables","Value":"62"},{"CounterName":"Disk Space in Bytes","Value":"147456"}]},{"Host":"testhost","ObjectName":"MySQL Database","InstanceName":"kab-cen-oms1:127.0.0.1:3306:mysql","Collections":[{"CounterName":"Tables","Value":"24"},{"CounterName":"Disk Space in Bytes","Value":"656438"}]}]
		transform_validate_records_helper(expected_mysqldb_record, mysqldb_perf_record , all_performance_counters, "MySQL DB Input Class Failed!")

   		#Test MySQL_ServerStatistics
		mysql_perf_record = [{"ClassName"=>"MySQL_ServerStatistics","InstanceID"=>"kab-cen-oms1:127.0.0.1:3306","CurrentNumConnections"=>"1","MaxConnections"=>"151","Uptime"=>"4052","ServerDiskUseInBytes"=>"803894","ConnectionsUsePct"=>"1","AbortedConnectionPct"=>"0","SlowQueryPct"=>"0","KeyCacheHitPct"=>"0","KeyCacheWritePct"=>"0","KeyCacheUsePct"=>"18","QCacheHitPct"=>"0","QCachePrunesPct"=>"0","QCacheUsePct"=>"0","TCacheHitPct"=>"17","TableLockContentionPct"=>"0","TableCacheUsePct"=>"10","IDB_BP_HitPct"=>"100","IDB_BP_UsePct"=>"4","FullTableScanPct"=>"93"}]
		expected_mysql_record = [{"Host":"testhost","ObjectName":"MySQL Server","InstanceName":"kab-cen-oms1:127.0.0.1:3306","Collections":[{"CounterName":"Key Cache Hit Pct","Value":"0"},{"CounterName":"Key Cache Write Pct","Value":"0"},{"CounterName":"Key Cache Use Pct","Value":"18"},{"CounterName":"Query Cache Hit Pct","Value":"0"},{"CounterName":"Query Cache Use Pct","Value":"0"},{"CounterName":"Table Cache Hit Pct","Value":"17"},{"CounterName":"Table Lock Contention Pct","Value":"0"},{"CounterName":"Table Cache Use Pct","Value":"10"},{"CounterName":"InnoDB Buffer Pool Hit Pct","Value":"100"},{"CounterName":"InnoDB Buffer Pool Use Pct","Value":"4"},{"CounterName":"Full Table Scan Pct","Value":"93"},{"CounterName":"InnoDB Buffer Pool Use Pct","Value":"4"},{"CounterName":"Disk Space Use in Bytes","Value":"803894"},{"CounterName":"Connection Use Pct","Value":"1"},{"CounterName":"Aborted Connection Pct","Value":"0"}]}]
		transform_validate_records_helper(expected_mysql_record, mysql_perf_record , all_performance_counters, "MySQL Server Input Class Failed!")
	end
	
	def test_transform_class_returns_valid_record_filter_counters
		filtered_performance_counters = [
			'Processor % Processor Time',
			'Memory Available MBytes Memory',
			'Logical Disk % Free Inodes',
			'Physical Disk Physical Disk Bytes/sec',
			"Container Processor Usage sec",
			"System Uptime",
			"Process Pct User Time",
			"Apache HTTP Server Total Pct CPU",
			"Apache Virtual Host Requests per Second",
			"MySQL Database Tables",
			"MySQL Server Key Cache Hit Pct"
		]		


		# Test filtered SCX_RTProcessorStatisticalInformation
		processor_input_record = [{"ClassName"=>"SCX_RTProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"0","IsAggregate"=>"false","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"},{"ClassName"=>"SCX_RTProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"_Total","IsAggregate"=>"true","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"}]
		expected_processor_record = [{"Host":"testhost","ObjectName":"Processor","InstanceName":"0","Collections":[{"CounterName":"% Processor Time","Value":"0"}]},{"Host":"testhost","ObjectName":"Processor","InstanceName":"_Total","Collections":[{"CounterName":"% Processor Time","Value":"0"}]}]
		transform_validate_records_helper(expected_processor_record, processor_input_record, filtered_performance_counters, "Processor Filtered Input Class Failed!")

		# Test filtered SCX_MemoryStatiscalInformation
		memory_input_record = [{"ClassName"=>"SCX_MemoryStatisticalInformation","Caption"=>"Memory information","Description"=>"Memory usage and performance statistics","Name"=>"Memory","IsAggregate"=>"true","AvailableMemory"=>"269","PercentAvailableMemory"=>"23","UsedMemory"=>"904","PercentUsedMemory"=>"77","PercentUsedByCache"=>"0","PagesPerSec"=>"0","PagesReadPerSec"=>"0","PagesWrittenPerSec"=>"0","AvailableSwap"=>"1987","PercentAvailableSwap"=>"97","UsedSwap"=>"56","PercentUsedSwap"=>"3"}]
		expected_memory_record = [{"Host":"testhost","ObjectName":"Memory","InstanceName":"Memory","Collections":[{"CounterName":"Available MBytes Memory","Value":"269"}]}]
		transform_validate_records_helper(expected_memory_record, memory_input_record, filtered_performance_counters, "Memory Filtered Input Class Failed!")
		
		# Test filtered SCX_FileSystemStatisticalInformation
		file_input_record = [{"ClassName"=>"SCX_FileSystemStatisticalInformation","Caption"=>"File system information","Description"=>"Performance statistics related to a logical unit of secondary storage","Name"=>"/","IsAggregate"=>"false","IsOnline"=>"true","FreeMegabytes"=>"87400","UsedMegabytes"=>"10991","PercentFreeSpace"=>"89","PercentUsedSpace"=>"11","PercentFreeInodes"=>"96","PercentUsedInodes"=>"4","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0"},{"ClassName"=>"SCX_FileSystemStatisticalInformation","Caption"=>"File system information","Description"=>"Performance statistics related to a logical unit of secondary storage","Name"=>"/boot","IsAggregate"=>"false","IsOnline"=>"true","FreeMegabytes"=>"99","UsedMegabytes"=>"137","PercentFreeSpace"=>"42","PercentUsedSpace"=>"58","PercentFreeInodes"=>"99","PercentUsedInodes"=>"1","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0"},{"ClassName"=>"SCX_FileSystemStatisticalInformation","Caption"=>"File system information","Description"=>"Performance statistics related to a logical unit of secondary storage","Name"=>"_Total","IsAggregate"=>"true","IsOnline"=>"true","FreeMegabytes"=>"87499","UsedMegabytes"=>"11128","PercentFreeSpace"=>"89","PercentUsedSpace"=>"11","PercentFreeInodes"=>"100","PercentUsedInodes"=>"0","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0"}]
		expected_file_record = [{"Host":"testhost","ObjectName":"Logical Disk","InstanceName":"/","Collections":[{"CounterName":"% Free Inodes","Value":"96"}]},{"Host":"testhost","ObjectName":"Logical Disk","InstanceName":"/boot","Collections":[{"CounterName":"% Free Inodes","Value":"99"}]},{"Host":"testhost","ObjectName":"Logical Disk","InstanceName":"_Total","Collections":[{"CounterName":"% Free Inodes","Value":"100"}]}]
		transform_validate_records_helper(expected_file_record, file_input_record, filtered_performance_counters, "File Filtered Input Class Failed!")
		
		# Test filtered SCX_DiskDriveStatiscalInformation
		disk_input_record = [{"ClassName"=>"SCX_DiskDriveStatisticalInformation","Caption"=>"Disk drive information","Description"=>"Performance statistics related to a physical unit of secondary storage","Name"=>"sda","IsAggregate"=>"false","IsOnline"=>"true","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0","AverageReadTime"=>"0","AverageWriteTime"=>"0","AverageTransferTime"=>"0","AverageDiskQueueLength"=>"0"},{"ClassName"=>"SCX_DiskDriveStatisticalInformation","Caption"=>"Disk drive information","Description"=>"Performance statistics related to a physical unit of secondary storage","Name"=>"_Total","IsAggregate"=>"true","IsOnline"=>"true","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0","AverageReadTime"=>"0","AverageWriteTime"=>"0","AverageTransferTime"=>"0","AverageDiskQueueLength"=>"0"}]
		expected_disk_record = [{"Host":"testhost","ObjectName":"Physical Disk","InstanceName":"sda","Collections":[{"CounterName":"Physical Disk Bytes/sec","Value":"0"}]},{"Host":"testhost","ObjectName":"Physical Disk","InstanceName":"_Total","Collections":[{"CounterName":"Physical Disk Bytes/sec","Value":"0"}]}]
		transform_validate_records_helper(expected_disk_record, disk_input_record, filtered_performance_counters, "Disk Filtered Input Class Failed!")
		
		# Test Container_ContainerStatistics
		container_perf_record = [{"ClassName"=>"Container_ContainerStatistics","InstanceID"=>"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","ElementName"=>"hello","CPUTotal"=>"5","CPUTotalPct"=>"1","MemUsedMB"=>"64","NetRXBytes"=>"256","NetTXBytes"=>"256","DiskBytesRead"=>"10","DiskBytesWritten"=>"2"}]
		expected_container_record = [{"Host":"testhost","ObjectName":"Container","InstanceName":"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","Collections":[{"CounterName":"Processor Usage sec","Value":"5"}]}]
		transform_validate_records_helper(expected_container_record, container_perf_record, filtered_performance_counters, "Filtered Container Input Class Failed!")

		# Test SCX_OperatingSystem
		operatingsystem_perf_record = [{"ClassName"=>"SCX_OperatingSystem","Caption"=>"CentOS Linux 7.0 (x86_64)","Description"=>"CentOS Linux 7.0 (x86_64)","Name"=>"Linux Distribution","EnabledState"=>"5","RequestedState"=>"12","EnabledDefault"=>"2","CSCreationClassName"=>"SCX_ComputerSystem","CSName"=>"kab-cen-oms1.scx.com","CreationClassName"=>"SCX_OperatingSystem","OSType"=>"36","OtherTypeDescription"=>"3.10.0-123.el7.x86_64 #1 SMP Mon Jun 30 12:09:22 UTC 2014 x86_64","Version"=>"7.0","LastBootUpTime"=>"20151004103518.000000+000","LocalDateTime"=>"20151013132103.687815+000","CurrentTimeZone"=>"-420","NumberOfLicensedUsers"=>"0","NumberOfUsers"=>"1","NumberOfProcesses"=>"251","MaxNumberOfProcesses"=>"15515","TotalSwapSpaceSize"=>"1048572","TotalVirtualMemorySize"=>"2059520","FreeVirtualMemory"=>"1787396","FreePhysicalMemory"=>"738824","TotalVisibleMemorySize"=>"1010948","SizeStoredInPagingFiles"=>"1048572","FreeSpaceInPagingFiles"=>"1048572","MaxProcessMemorySize"=>"0","MaxProcessesPerUser"=>"7757","OperatingSystemCapability"=>"64 bit","SystemUpTime"=>"762352"		}]
		expected_operatingsystem_record = [{"Host":"testhost", "ObjectName":"System","InstanceName":"CentOS Linux 7.0 (x86_64)","Collections":[{"CounterName":"Uptime","Value":"762352"}]}]
		transform_validate_records_helper(expected_operatingsystem_record, operatingsystem_perf_record , filtered_performance_counters, "Filtered OperatingSystem Input Class Failed!")

		#Test SCX_UnixProcessStatisticalInformation
		process_perf_record = [{"ClassName"=>"SCX_UnixProcessStatisticalInformation","Caption"=>"Unix process information","Description"=>"A snapshot of a current process","Name"=>"omsagent","CSCreationClassName"=>"SCX_ComputerSystem","CSName"=>"kab-cen-oms1.scx.com","OSCreationClassName"=>"SCX_OperatingSystem","OSName"=>"Linux Distribution","Handle"=>"28402","ProcessCreationClassName"=>"SCX_UnixProcessStatisticalInformation","CPUTime"=>"0","VirtualText"=>"2666496","VirtualData"=>"953671680","VirtualSharedMemory"=>"5216","CpuTimeDeadChildren"=>"180","SystemTimeDeadChildren"=>"123","PercentUserTime"=>"0","PercentPrivilegedTime"=>"0","UsedMemory"=>"40208","PercentUsedMemory"=>"3","PagesReadPerSec"=>"0"}]
		expected_process_record = [{"Host":"testhost", "ObjectName":"Process","InstanceName":"omsagent","Collections":[{"CounterName":"Pct User Time","Value":"0"}]}]
		transform_validate_records_helper(expected_process_record, process_perf_record , filtered_performance_counters, "Filtered Process Input Class Failed!")

		#Test Apache_HTTPDServerStatistics
		apacheserver_perf_record = [{"ClassName"=>"Apache_HTTPDServerStatistics","InstanceID"=>"/etc/httpd/conf/httpd.conf","TotalPctCPU"=>"0","IdleWorkers"=>"0","BusyWorkers"=>"0","PctBusyWorkers"=>"0","ConfigurationFile"=>"/etc/httpd/conf/httpd.conf"}]
		expected_apacheserver_record = [{"Host":"testhost", "ObjectName":"Apache HTTP Server","InstanceName":"/etc/httpd/conf/httpd.conf","Collections":[{"CounterName":"Total Pct CPU","Value":"0"}]}]
		transform_validate_records_helper(expected_apacheserver_record, apacheserver_perf_record , filtered_performance_counters, "Filtered Apache Server Input Class Failed!")

		#Test Apache_HTTPDVirtualHostStatistics
		apachevhost_perf_record = [{"ClassName"=>"Apache_HTTPDVirtualHostStatistics","InstanceID"=>"10.184.145.57,_default_:0","ServerName"=>"10.184.145.57","RequestsTotal"=>"0","RequestsTotalBytes"=>"0","RequestsPerSecond"=>"0","KBPerRequest"=>"0","KBPerSecond"=>"0","ErrorCount400"=>"0","ErrorCount500"=>"0","ErrorsPerMinute400"=>"0","ErrorsPerMinute500"=>"0"},{"ClassName"=>"Apache_HTTPDVirtualHostStatistics","InstanceID"=>"_Total","ServerName"=>"_Total","RequestsTotal"=>"0","RequestsTotalBytes"=>"0","RequestsPerSecond"=>"0","KBPerRequest"=>"0","KBPerSecond"=>"0","ErrorCount400"=>"0","ErrorCount500"=>"0","ErrorsPerMinute400"=>"0","ErrorsPerMinute500"=>"0"}]
		expected_apachevhost_record = [{"Host":"testhost","ObjectName":"Apache Virtual Host","InstanceName":"10.184.145.57,_default_:0","Collections":[{"CounterName":"Requests per Second","Value":"0"}]},{"Host":"testhost","ObjectName":"Apache Virtual Host","InstanceName":"_Total","Collections":[{"CounterName":"Requests per Second","Value":"0"}]}]
		transform_validate_records_helper(expected_apachevhost_record, apachevhost_perf_record , filtered_performance_counters, "Filtered Apache VHost Input Class Failed!")

		#Test MySQL_Server_Database
		mysqldb_perf_record = [{"ClassName"=>"MySQL_Server_Database","InstanceID"=>"kab-cen-oms1:127.0.0.1:3306:information_schema","DatabaseName"=>"information_schema","NumberOfTables"=>"62","DiskSpaceInBytes"=>"147456"},{"ClassName"=>"MySQL_Server_Database","InstanceID"=>"kab-cen-oms1:127.0.0.1:3306:mysql","DatabaseName"=>"mysql","NumberOfTables"=>"24","DiskSpaceInBytes"=>"656438"}]
		expected_mysqldb_record = [{"Host":"testhost","ObjectName":"MySQL Database","InstanceName":"kab-cen-oms1:127.0.0.1:3306:information_schema","Collections":[{"CounterName":"Tables","Value":"62"}]},{"Host":"testhost","ObjectName":"MySQL Database","InstanceName":"kab-cen-oms1:127.0.0.1:3306:mysql","Collections":[{"CounterName":"Tables","Value":"24"}]}]
		transform_validate_records_helper(expected_mysqldb_record, mysqldb_perf_record , filtered_performance_counters, "Filtered MySQL DB Input Class Failed!")
		
   		#Test MySQL_ServerStatistics
		mysql_perf_record = [{"ClassName"=>"MySQL_ServerStatistics","InstanceID"=>"kab-cen-oms1:127.0.0.1:3306","CurrentNumConnections"=>"1","MaxConnections"=>"151","Uptime"=>"4052","ServerDiskUseInBytes"=>"803894","ConnectionsUsePct"=>"1","AbortedConnectionPct"=>"0","SlowQueryPct"=>"0","KeyCacheHitPct"=>"0","KeyCacheWritePct"=>"0","KeyCacheUsePct"=>"18","QCacheHitPct"=>"0","QCachePrunesPct"=>"0","QCacheUsePct"=>"0","TCacheHitPct"=>"17","TableLockContentionPct"=>"0","TableCacheUsePct"=>"10","IDB_BP_HitPct"=>"100","IDB_BP_UsePct"=>"4","FullTableScanPct"=>"93"}]
		expected_mysql_record = [{"Host":"testhost","ObjectName":"MySQL Server","InstanceName":"kab-cen-oms1:127.0.0.1:3306","Collections":[{"CounterName":"Key Cache Hit Pct","Value":"0"}]}]
		transform_validate_records_helper(expected_mysql_record, mysql_perf_record , filtered_performance_counters, "Filtered MySQL Server Input Class Failed!")
	end

	def test_transform_class_returns_valid_record_filter_out_all_counters
		# Test no perf counters selected SCX_RTProcessorStatisticalInformation
		processor_input_record = [{"ClassName"=>"SCX_RTProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"0","IsAggregate"=>"false","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"},{"ClassName"=>"SCX_RTProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"_Total","IsAggregate"=>"true","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"}]
		expected_processor_record = [{"Host":"testhost","ObjectName":"Processor","InstanceName":"0","Collections":[]},{"Host":"testhost","ObjectName":"Processor","InstanceName":"_Total","Collections":[]}]
		transform_validate_records_helper(expected_processor_record, processor_input_record, [], "Processor No Perf Counters Input Class Failed!")

		# Test filtered SCX_MemoryStatiscalInformation
		memory_input_record = [{"ClassName"=>"SCX_MemoryStatisticalInformation","Caption"=>"Memory information","Description"=>"Memory usage and performance statistics","Name"=>"Memory","IsAggregate"=>"true","AvailableMemory"=>"269","PercentAvailableMemory"=>"23","UsedMemory"=>"904","PercentUsedMemory"=>"77","PercentUsedByCache"=>"0","PagesPerSec"=>"0","PagesReadPerSec"=>"0","PagesWrittenPerSec"=>"0","AvailableSwap"=>"1987","PercentAvailableSwap"=>"97","UsedSwap"=>"56","PercentUsedSwap"=>"3"}]
		expected_memory_record = [{"Host":"testhost","ObjectName":"Memory","InstanceName":"Memory","Collections":[]}]
		transform_validate_records_helper(expected_memory_record, memory_input_record, [], "Memory Filtered Input Class Failed!")
		
		# Test no perf counters selected SCX_FileSystemStatisticalInformation
		file_input_record = [{"ClassName"=>"SCX_FileSystemStatisticalInformation","Caption"=>"File system information","Description"=>"Performance statistics related to a logical unit of secondary storage","Name"=>"/","IsAggregate"=>"false","IsOnline"=>"true","FreeMegabytes"=>"87400","UsedMegabytes"=>"10991","PercentFreeSpace"=>"89","PercentUsedSpace"=>"11","PercentFreeInodes"=>"96","PercentUsedInodes"=>"4","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0"},{"ClassName"=>"SCX_FileSystemStatisticalInformation","Caption"=>"File system information","Description"=>"Performance statistics related to a logical unit of secondary storage","Name"=>"/boot","IsAggregate"=>"false","IsOnline"=>"true","FreeMegabytes"=>"99","UsedMegabytes"=>"137","PercentFreeSpace"=>"42","PercentUsedSpace"=>"58","PercentFreeInodes"=>"99","PercentUsedInodes"=>"1","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0"},{"ClassName"=>"SCX_FileSystemStatisticalInformation","Caption"=>"File system information","Description"=>"Performance statistics related to a logical unit of secondary storage","Name"=>"_Total","IsAggregate"=>"true","IsOnline"=>"true","FreeMegabytes"=>"87499","UsedMegabytes"=>"11128","PercentFreeSpace"=>"89","PercentUsedSpace"=>"11","PercentFreeInodes"=>"100","PercentUsedInodes"=>"0","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0"}]
		expected_file_record = [{"Host":"testhost","ObjectName":"Logical Disk","InstanceName":"/","Collections":[]},{"Host":"testhost","ObjectName":"Logical Disk","InstanceName":"/boot","Collections":[]},{"Host":"testhost","ObjectName":"Logical Disk","InstanceName":"_Total","Collections":[]}]
		transform_validate_records_helper(expected_file_record, file_input_record, [], "File Filtered Input Class Failed!")
		
		# Test no perf counters selected SCX_DiskDriveStatiscalInformation
		disk_input_record = [{"ClassName"=>"SCX_DiskDriveStatisticalInformation","Caption"=>"Disk drive information","Description"=>"Performance statistics related to a physical unit of secondary storage","Name"=>"sda","IsAggregate"=>"false","IsOnline"=>"true","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0","AverageReadTime"=>"0","AverageWriteTime"=>"0","AverageTransferTime"=>"0","AverageDiskQueueLength"=>"0"},{"ClassName"=>"SCX_DiskDriveStatisticalInformation","Caption"=>"Disk drive information","Description"=>"Performance statistics related to a physical unit of secondary storage","Name"=>"_Total","IsAggregate"=>"true","IsOnline"=>"true","BytesPerSecond"=>"0","ReadBytesPerSecond"=>"0","WriteBytesPerSecond"=>"0","TransfersPerSecond"=>"0","ReadsPerSecond"=>"0","WritesPerSecond"=>"0","AverageReadTime"=>"0","AverageWriteTime"=>"0","AverageTransferTime"=>"0","AverageDiskQueueLength"=>"0"}]
		expected_disk_record = [{"Host":"testhost","ObjectName":"Physical Disk","InstanceName":"sda","Collections":[]},{"Host":"testhost","ObjectName":"Physical Disk","InstanceName":"_Total","Collections":[]}]
		transform_validate_records_helper(expected_disk_record, disk_input_record, [], "Disk Filtered Input Class Failed!")
		
		# Test Container_ContainerStatistics
		container_perf_record = [{"ClassName"=>"Container_ContainerStatistics","InstanceID"=>"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","ElementName"=>"hello","CPUTotal"=>"5","CPUTotalPct"=>"1","MemUsedMB"=>"64","NetRXBytes"=>"256","NetTXBytes"=>"256","DiskBytesRead"=>"10","DiskBytesWritten"=>"2"}]
		expected_container_record = [{"Host":"testhost","ObjectName":"Container","InstanceName":"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","Collections":[]}]
		transform_validate_records_helper(expected_container_record, container_perf_record, [], "Container Input Class with no counters Failed!")

		# Test SCX_OperatingSystem
		operatingsystem_perf_record = [{"ClassName"=>"SCX_OperatingSystem","Caption"=>"CentOS Linux 7.0 (x86_64)","Description"=>"CentOS Linux 7.0 (x86_64)","Name"=>"Linux Distribution","EnabledState"=>"5","RequestedState"=>"12","EnabledDefault"=>"2","CSCreationClassName"=>"SCX_ComputerSystem","CSName"=>"kab-cen-oms1.scx.com","CreationClassName"=>"SCX_OperatingSystem","OSType"=>"36","OtherTypeDescription"=>"3.10.0-123.el7.x86_64 #1 SMP Mon Jun 30 12:09:22 UTC 2014 x86_64","Version"=>"7.0","LastBootUpTime"=>"20151004103518.000000+000","LocalDateTime"=>"20151013132103.687815+000","CurrentTimeZone"=>"-420","NumberOfLicensedUsers"=>"0","NumberOfUsers"=>"1","NumberOfProcesses"=>"251","MaxNumberOfProcesses"=>"15515","TotalSwapSpaceSize"=>"1048572","TotalVirtualMemorySize"=>"2059520","FreeVirtualMemory"=>"1787396","FreePhysicalMemory"=>"738824","TotalVisibleMemorySize"=>"1010948","SizeStoredInPagingFiles"=>"1048572","FreeSpaceInPagingFiles"=>"1048572","MaxProcessMemorySize"=>"0","MaxProcessesPerUser"=>"7757","OperatingSystemCapability"=>"64 bit","SystemUpTime"=>"762352"		}]
		expected_operatingsystem_record = [{"Host":"testhost", "ObjectName":"System","InstanceName":"CentOS Linux 7.0 (x86_64)","Collections":[]}]
		transform_validate_records_helper(expected_operatingsystem_record, operatingsystem_perf_record , [], "OperatingSystem Input with no counters Failed!")

		#Test SCX_UnixProcessStatisticalInformation
		process_perf_record = [{"ClassName"=>"SCX_UnixProcessStatisticalInformation","Caption"=>"Unix process information","Description"=>"A snapshot of a current process","Name"=>"omsagent","CSCreationClassName"=>"SCX_ComputerSystem","CSName"=>"kab-cen-oms1.scx.com","OSCreationClassName"=>"SCX_OperatingSystem","OSName"=>"Linux Distribution","Handle"=>"28402","ProcessCreationClassName"=>"SCX_UnixProcessStatisticalInformation","CPUTime"=>"0","VirtualText"=>"2666496","VirtualData"=>"953671680","VirtualSharedMemory"=>"5216","CpuTimeDeadChildren"=>"180","SystemTimeDeadChildren"=>"123","PercentUserTime"=>"0","PercentPrivilegedTime"=>"0","UsedMemory"=>"40208","PercentUsedMemory"=>"3","PagesReadPerSec"=>"0"}]
		expected_process_record = [{"Host":"testhost", "ObjectName":"Process","InstanceName":"omsagent","Collections":[]}]
		transform_validate_records_helper(expected_process_record, process_perf_record , [], "Process Input with no counters Failed!")

		#Test Apache_HTTPDServerStatistics
		apacheserver_perf_record = [{"ClassName"=>"Apache_HTTPDServerStatistics","InstanceID"=>"/etc/httpd/conf/httpd.conf","TotalPctCPU"=>"0","IdleWorkers"=>"0","BusyWorkers"=>"0","PctBusyWorkers"=>"0","ConfigurationFile"=>"/etc/httpd/conf/httpd.conf"}]
		expected_apacheserver_record = [{"Host":"testhost", "ObjectName":"Apache HTTP Server","InstanceName":"/etc/httpd/conf/httpd.conf","Collections":[]}]
		transform_validate_records_helper(expected_apacheserver_record, apacheserver_perf_record , [], "Apache Server with no counters Failed!")

		#Test Apache_HTTPDVirtualHostStatistics
		apachevhost_perf_record = [{"ClassName"=>"Apache_HTTPDVirtualHostStatistics","InstanceID"=>"10.184.145.57,_default_:0","ServerName"=>"10.184.145.57","RequestsTotal"=>"0","RequestsTotalBytes"=>"0","RequestsPerSecond"=>"0","KBPerRequest"=>"0","KBPerSecond"=>"0","ErrorCount400"=>"0","ErrorCount500"=>"0","ErrorsPerMinute400"=>"0","ErrorsPerMinute500"=>"0"},{"ClassName"=>"Apache_HTTPDVirtualHostStatistics","InstanceID"=>"_Total","ServerName"=>"_Total","RequestsTotal"=>"0","RequestsTotalBytes"=>"0","RequestsPerSecond"=>"0","KBPerRequest"=>"0","KBPerSecond"=>"0","ErrorCount400"=>"0","ErrorCount500"=>"0","ErrorsPerMinute400"=>"0","ErrorsPerMinute500"=>"0"}]
		expected_apachevhost_record = [{"Host":"testhost","ObjectName":"Apache Virtual Host","InstanceName":"10.184.145.57,_default_:0","Collections":[]},{"Host":"testhost","ObjectName":"Apache Virtual Host","InstanceName":"_Total","Collections":[]}]
		transform_validate_records_helper(expected_apachevhost_record, apachevhost_perf_record , [], "Apache VHost with no counters Failed!")

		#Test MySQL_Server_Database
		mysqldb_perf_record = [{"ClassName"=>"MySQL_Server_Database","InstanceID"=>"kab-cen-oms1:127.0.0.1:3306:information_schema","DatabaseName"=>"information_schema","NumberOfTables"=>"62","DiskSpaceInBytes"=>"147456"},{"ClassName"=>"MySQL_Server_Database","InstanceID"=>"kab-cen-oms1:127.0.0.1:3306:mysql","DatabaseName"=>"mysql","NumberOfTables"=>"24","DiskSpaceInBytes"=>"656438"}]
		expected_mysqldb_record = [{"Host":"testhost","ObjectName":"MySQL Database","InstanceName":"kab-cen-oms1:127.0.0.1:3306:information_schema","Collections":[]},{"Host":"testhost","ObjectName":"MySQL Database","InstanceName":"kab-cen-oms1:127.0.0.1:3306:mysql","Collections":[]}]
		transform_validate_records_helper(expected_mysqldb_record, mysqldb_perf_record , [], "MySQL DB with no counters Failed!")

		#Test MySQL_ServerStatistics
		mysql_perf_record = [{"ClassName"=>"MySQL_ServerStatistics","InstanceID"=>"kab-cen-oms1:127.0.0.1:3306","CurrentNumConnections"=>"1","MaxConnections"=>"151","Uptime"=>"4052","ServerDiskUseInBytes"=>"803894","ConnectionsUsePct"=>"1","AbortedConnectionPct"=>"0","SlowQueryPct"=>"0","KeyCacheHitPct"=>"0","KeyCacheWritePct"=>"0","KeyCacheUsePct"=>"18","QCacheHitPct"=>"0","QCachePrunesPct"=>"0","QCacheUsePct"=>"0","TCacheHitPct"=>"17","TableLockContentionPct"=>"0","TableCacheUsePct"=>"10","IDB_BP_HitPct"=>"100","IDB_BP_UsePct"=>"4","FullTableScanPct"=>"93"}]
		expected_mysql_record = [{"Host":"testhost","ObjectName":"MySQL Server","InstanceName":"kab-cen-oms1:127.0.0.1:3306","Collections":[]}]
		transform_validate_records_helper(expected_mysql_record, mysql_perf_record , [], "Filtered MySQL Server Input Class Failed!")

	end
end
