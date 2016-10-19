require 'fluent/test'
require 'fluent/test/parser_test'
require_relative '../../../source/code/plugins/parser_vmware_logs.rb'
require_relative 'omstestlib'

class VmwareSyslogParserTest < Test::Unit::TestCase

  CONFIG = %[
    format vmware_parser
    time_format %Y-%m-%dT%H:%M:%S.%L%Z
  ]

  def create_driver
    Fluent::Test::ParserTestDriver.new(Fluent::TextParser::VMwareSyslogParser.new).configure(CONFIG)
  end

  def test_parse
    d = create_driver()
    text = '2016-09-14T14:14:25.234Z contosa.vm.esxi1 vmkernel: cpu0:33011)WARNING: IOMMUIntel: 2777: IOMMU context entry dump for 0000:06:00.0 Ctx-Hi = 0xf000a835f000e2c3 Ctx-Lo = 0xf000a835f000a835'
    d.instance.parse(text) do |_time, record|
      assert_equal record['HostName'], 'contosa.vm.esxi1'
      assert_equal record['ProcessName'], 'vmkernel'
      assert_equal record['SyslogMessage'], "cpu0:33011)WARNING: IOMMUIntel: 2777: IOMMU context entry dump for 0000:06:00.0 Ctx-Hi = 0xf000a835f000e2c3 Ctx-Lo = 0xf000a835f000a835"
      assert_equal record['ESXIFailure'], ''
      assert_equal record['Operation'], ''
    end

    text = '2016-09-14T14:14:25.234Z contosa.vm.esxi1 vmkernel[34242432]: cpu0:33011)WARNING: IOMMUIntel: 2777: IOMMU context entry dump for 0000:06:00.0 Ctx-Hi = 0xf000a835f000e2c3 Ctx-Lo = 0xf000a835f000a835'
    d.instance.parse(text) do |_time, record|
      assert_equal record['HostName'], 'contosa.vm.esxi1'
      assert_equal record['ProcessName'], 'vmkernel'
      assert_equal record['SyslogMessage'], "cpu0:33011)WARNING: IOMMUIntel: 2777: IOMMU context entry dump for 0000:06:00.0 Ctx-Hi = 0xf000a835f000e2c3 Ctx-Lo = 0xf000a835f000a835"
      assert_equal record['ESXIFailure'], ''
      assert_equal record['Operation'], ''
    end
  end

  def test_message_parsing_fields
    # Parse Device from message field
    device = create_driver()
    text = '2016-09-14T14:14:25.234Z contosa.vm.esxi1 vmkernel: reservation state on device naa.6006016084b02800b4a07969cd74e011 is unknown'
    device.instance.parse(text) do |_time, record|
      assert_equal record['Device'], 'naa.6006016084b02800b4a07969cd74e011'
      assert_equal record['ESXIFailure'], ''
      assert_equal record['Operation'], ''
    end

    # Parse SCSIStatus from message field
    scsi = create_driver()
    text = "2016-09-14T14:14:25.234Z contosa.vm.esxi1 vmkernel: Cmd 0x1a (0x439d8039e400, 0) to dev 'mpx.vmhba32:C0:T0:L0' on path 'vmhba32:C0:T0:L0' Failed: H:0x0 D:0x2 P:0x0 Valid sense data: 0x5 0x24 0x0."
    scsi.instance.parse(text) do |_time, record|
      assert_equal record['SCSIStatus'], 'H:0x0 D:0x2 P:0x0'
    end

    # Parse ESXIFailure from message field
    status = create_driver()
    text = '2016-09-14T14:14:25.234Z contosa.vm.esxi1 vobd: [scsiCorrelator] 14807183227307us: [esx.problem.scsi.device.io.latency.high] Device or filesystem with identifier [mpx.vmhba32:C0:T0:L0] Device naa.60a9800041764b6c463f437868556b7a performance has deteriorated'
    status.instance.parse(text) do |_time, record|
      assert_equal record['ESXIFailure'], 'scsi.device.io.latency.high'
      assert_equal record['Device'], 'naa.60a9800041764b6c463f437868556b7a'
    end

    # Parse multiple fields from the same message field
    latency = create_driver()
    text = '2016-09-14T14:14:25.234Z contosa.vm.esxi1 vobd: [scsiCorrelator] 14807183227307us: [esx.problem.scsi.device.io.latency.high] Device naa.60a9800041764b6c463f437868556b7a performance has deteriorated. I/O latency increased from average value of 1343 microseconds to 28022 microseconds.'
    latency.instance.parse(text) do |_time, record|
      assert_equal record['ESXIFailure'], 'scsi.device.io.latency.high'
      assert_equal record['Device'], 'naa.60a9800041764b6c463f437868556b7a'
      assert_equal record['StorageLatency'], 28022
      assert_equal record['Operation'], ''
    end

    # Parse fields when VM is Created
    vmcreation = create_driver()
    text = '2016-09-14T14:14:25.234Z contosa.vm.esxi1 hostd: info hostd[70840B70] [Originator@6876 sub=Vimsvc.ha-eventmgr opID=58B46869-0000005E-46-3d-df-5944 user=vpxuser:VSPHERE.LOCAL\Administrator] Event 616 : Created virtual machine TestVM2 on ESXik.corp.microsoft.com in ha-datacenter'
    vmcreation.instance.parse(text) do |_time, record|
      assert_equal record['UserName'], 'vpxuser:VSPHERE.LOCAL\Administrator'
      assert_equal record['VMName'], 'TestVM2'
      assert_equal record['DataCenter'], 'ha-datacenter'
      assert_equal record['Operation'], 'Create VM'
    end

    # Parse fields when VM is Removed
    vmdeletion = create_driver()
    text = '2016-09-14T14:14:25.234Z contosa.vm.esxi1 hostd: info hostd[FFF35AE0] [Originator@6876 sub=Vimsvc.ha-eventmgr opID=A0242BED-000000C8-d6-d8-2b13 user=vpxuser:VSPHERE.LOCAL\Administrator] Event 340 : Removed testvm4 on ESXik.corp.microsoft.com from ha-datacenter'
    vmdeletion.instance.parse(text) do |_time, record|
      assert_equal record['UserName'], 'vpxuser:VSPHERE.LOCAL\Administrator'
      assert_equal record['VMName'], 'testvm4'
      assert_equal record['DataCenter'], 'ha-datacenter'
      assert_equal record['Operation'], 'Delete VM'
    end

    # Should not emit for blacklisted process names
    blacklist1 = create_driver()
    text = '2016-09-14T14:14:25.234Z contosa.vm.esxi1 crond[23424]: info hostd[FFF35AE0] [Originator@6876 sub=Vimsvc.ha-eventmgr'
    assert_equal blacklist1.instance.parse(text), nil

    blacklist2 = create_driver()
    text = '2016-09-14T14:14:25.234Z contosa.vm.esxi1 omsagent: info hostd[FFF35AE0] [Originator@6876 sub=Vimsvc.ha-eventmgr'
    assert_equal blacklist2.instance.parse(text), nil
  end

  def test_outgoing_logs_format
    d1 = create_driver()
    text = '2016-09-14T14:14:25.234Z contosa.vm.esxi1 vmkernel: [scsiCorrelator] 14807183227307us: [esx.problem.scsi.device.io.latency.high] Device naa.60a9800041764b6c463f437868556b7a performance has deteriorated'
    d1.instance.parse(text) do |_time, record|
      assert_equal Hash, record.class
    end
  end
end
