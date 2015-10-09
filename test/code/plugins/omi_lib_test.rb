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
			@@omi_lib = OmiModule::Omi.new(TestRuntimeError2.new, "omi_mapping.json")
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
			"Container Disk Writes MB"
		]
	
		# Test SCX_ProcessorStatisticalInformation
		processor_input_record = [{"ClassName"=>"SCX_ProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"0","IsAggregate"=>"false","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"},{"ClassName"=>"SCX_ProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"_Total","IsAggregate"=>"true","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"}]
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
		container_perf_record = [{"ClassName"=>"Container_ContainerStatistics","InstanceID"=>"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","ElementName"=>"hello","CPUTotal"=>"5","CPUTotalPct"=>"1","MemUsedPct"=>"64","NetRXBytes"=>"256","NetTXBytes"=>"256","DiskBytesRead"=>"10","DiskBytesWritten"=>"2"}]
		expected_container_record = [{"Host":"testhost","ObjectName":"Container","InstanceName":"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","Collections":[{"CounterName":"Processor Usage sec","Value":"5"},{"CounterName":"% Processor Time","Value":"1"},{"CounterName":"Memory Usage MB","Value":"64"},{"CounterName":"Network Receive Bytes","Value":"256"},{"CounterName":"Network Send Bytes","Value":"256"},{"CounterName":"Disk Reads MB","Value":"10"},{"CounterName":"Disk Writes MB","Value":"2"}]}]
		transform_validate_records_helper(expected_container_record, container_perf_record, all_performance_counters, "Container Input Class Failed!")
	end
	
	def test_transform_class_returns_valid_record_filter_counters
		filtered_performance_counters = [
			'Processor % Processor Time',
			'Memory Available MBytes Memory',
			'Logical Disk % Free Inodes',
			'Physical Disk Physical Disk Bytes/sec',
			"Container Processor Usage sec"
		]		

		# Test filtered SCX_ProcessorStatisticalInformation
		processor_input_record = [{"ClassName"=>"SCX_ProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"0","IsAggregate"=>"false","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"},{"ClassName"=>"SCX_ProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"_Total","IsAggregate"=>"true","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"}]
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
		container_perf_record = [{"ClassName"=>"Container_ContainerStatistics","InstanceID"=>"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","ElementName"=>"hello","CPUTotal"=>"5","CPUTotalPct"=>"1","MemUsedPct"=>"64","NetRXBytes"=>"256","NetTXBytes"=>"256","DiskBytesRead"=>"10","DiskBytesWritten"=>"2"}]
		expected_container_record = [{"Host":"testhost","ObjectName":"Container","InstanceName":"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","Collections":[{"CounterName":"Processor Usage sec","Value":"5"}]}]
		transform_validate_records_helper(expected_container_record, container_perf_record, filtered_performance_counters, "Filtered Container Input Class Failed!")
	end

	def test_transform_class_returns_valid_record_filter_out_all_counters
		# Test no perf counters selected SCX_ProcessorStatisticalInformation
		processor_input_record = [{"ClassName"=>"SCX_ProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"0","IsAggregate"=>"false","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"},{"ClassName"=>"SCX_ProcessorStatisticalInformation","Caption"=>"Processor information","Description"=>"CPU usage statistics","Name"=>"_Total","IsAggregate"=>"true","PercentIdleTime"=>"0","PercentUserTime"=>"0","PercentNiceTime"=>"0","PercentPrivilegedTime"=>"0","PercentInterruptTime"=>"0","PercentDPCTime"=>"0","PercentProcessorTime"=>"0","PercentIOWaitTime"=>"0"}]
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
		container_perf_record = [{"ClassName"=>"Container_ContainerStatistics","InstanceID"=>"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","ElementName"=>"hello","CPUTotal"=>"5","CPUTotalPct"=>"1","MemUsedPct"=>"64","NetRXBytes"=>"256","NetTXBytes"=>"256","DiskBytesRead"=>"10","DiskBytesWritten"=>"2"}]
		expected_container_record = [{"Host":"testhost","ObjectName":"Container","InstanceName":"d1cbb7d89ccbaf29c0f5c90d965cd00e4379a0303041df75bf2ba1c71ee34d3b","Collections":[]}]
		transform_validate_records_helper(expected_container_record, container_perf_record, [], "Container Input Class with no counters Failed!")
	end
end
