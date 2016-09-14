require 'fluent/test'

require_relative '../../../source/code/plugins/filter_vmware_logs.rb'
require_relative 'omstestlib'

class VmwareSyslogFilterTest < Test::Unit::TestCase

  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
  ]

  def create_driver(conf = CONFIG, tag = 'oms.api.vmware')
    Fluent::Test::FilterTestDriver.new(Fluent::VmwareSyslogFilter, tag).configure(conf)
  end

  # Test for reqular scenarios
  def test_log_tokanization_success
    d1 = create_driver
    d1.run do
      d1.filter('message' => "2016-08-29 13:38:01 : 2016-08-29 13:38:00 : esxi1.schakra.int : 10.0.1.110 : 3 : info : root :  vsanObserver.sh: vsantraced is not started - can't start vsanObserver")
    end
    filtered = d1.filtered_as_array
    
    assert_equal filtered[0][2][:EventTime], '2016-08-29 13:38:00'
    assert_equal filtered[0][2][:HostIP], '10.0.1.110'
    assert_equal filtered[0][2][:HostName], 'esxi1.schakra.int'
    assert_equal filtered[0][2][:ProcessName], 'root'
  end

  # Test for incorrect scenarios
  def test_log_tokanization_failure
    d1 = create_driver
    d1.run do
      d1.filter('message' => "2016-08-29 13:38:01 : 2016-08-29 13:38:00")
    end
    filtered = d1.filtered_as_array
    assert_equal filtered[0][2][:EventTime], '2016-08-29 13:38:00'
    assert_equal filtered[0][2][:HostIP], nil
    assert_equal filtered[0][2][:HostName], nil
    assert_equal filtered[0][2][:ProcessName], nil
  end

  # Test for the parsing of message fields
  def test_message_parsing_fields
    # Parse Device from message field
    device = create_driver
    device.run do
      device.filter('message' => "2016-08-29 13:38:01 : 2016-08-29 13:38:01 : esxi1.schakra.int : 10.0.1.110 : 3 : info : root :  vsanObserver.sh:  reservation state on device naa.6006016084b02800b4a07969cd74e011 is unknown")
    end
    assert_equal device.filtered_as_array[0][2][:Device], 'naa.6006016084b02800b4a07969cd74e011'

    # Parse SCSIStatus from message field
    scsi = create_driver
    scsi.run do
      scsi.filter('message' => "2016-08-29 13:38:01 : 2016-08-29 13:38:00 : esxi1.schakra.int : 10.0.1.110 : 3 : info : root : Cmd 0x1a (0x439d8039e400, 0) to dev 'mpx.vmhba32:C0:T0:L0' on path 'vmhba32:C0:T0:L0' Failed: H:0x0 D:0x2 P:0x0 Valid sense data: 0x5 0x24 0x0.")
    end
    assert_equal scsi.filtered_as_array[0][2][:SCSIStatus], 'H:0x0 D:0x2 P:0x0'

    # Parse ESXIStatus from message field
    status = create_driver
    status.run do
      status.filter('message' => "2016-08-29 13:38:01 : 2016-08-29 13:38:00 : esxi1.schakra.int : 10.0.1.110 : 3 : info : vobd : [scsiCorrelator] 14807183227307us: [esx.problem.scsi.device.io.latency.high] Device naa.60a9800041764b6c463f437868556b7a performance has deteriorated")
    end
    assert_equal status.filtered_as_array[0][2][:ESXIStatus], 'esx.problem.scsi.device.io.latency.high'
    assert_equal status.filtered_as_array[0][2][:Device], 'naa.60a9800041764b6c463f437868556b7a'

    # Parse multiple fields from the same message field
    latency = create_driver
    latency.run do
      latency.filter('message' => "2016-08-29 13:38:01 : 2016-08-29 13:38:00 : esxi1.schakra.int : 10.0.1.110 : 3 : info : vobd : [scsiCorrelator] 14807183227307us: [esx.problem.scsi.device.io.latency.high] Device naa.60a9800041764b6c463f437868556b7a performance has deteriorated. I/O latency increased from average value of 1343 microseconds to 28022 microseconds.")
    end
    assert_equal latency.filtered_as_array[0][2][:ESXIStatus], 'esx.problem.scsi.device.io.latency.high'
    assert_equal latency.filtered_as_array[0][2][:Device], 'naa.60a9800041764b6c463f437868556b7a'
    assert_equal latency.filtered_as_array[0][2][:StorageLatency], '28022'
  end

  # Test for log emit format from Filter to Output
  def test_outgoing_logs_format
    d1 = create_driver
    d1.run do
      d1.filter('message' => "2016-08-29 13:38:01 : 2016-08-29 13:38:00 : esxi1.schakra.int : 10.0.1.110 : 3 : info : root :  vsanObserver.sh: vsantraced is not started - can't start vsanObserver")
    end
    filtered = d1.filtered_as_array
    
    assert_equal Hash, filtered[0][2].class
  end
end
