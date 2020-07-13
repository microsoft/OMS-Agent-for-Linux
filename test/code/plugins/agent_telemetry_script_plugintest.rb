require 'test/unit'
require 'tempfile'
require 'time'
require 'flexmock/test_unit'
require_relative '../../../source/code/plugins/agent_telemetry_script'
require_relative '../../../source/code/plugins/oms_common'
require_relative 'omstestlib'

class TelemetryUnitTest < Test::Unit::TestCase

  include FlexMock::TestCase

  # Constants for testing
  VALID_AGENT_GUID = "4d593017-2e94-4d54-84ad-12d9d05e02ce"
  VALID_WORKSPACE_ID = "368a6f2a-1d36-4899-9415-20f44a5acd5d"
  VALID_DSC_ENDPOINT_NO_ESC = "https://oaasagentsvcdf.cloudapp.net/Accounts/#{VALID_WORKSPACE_ID}"\
                              "/Nodes(AgentId='#{VALID_AGENT_GUID}')"
  VALID_CERTIFICATE_UPDATE_ENDPOINT = "https://#{VALID_WORKSPACE_ID}.oms.int2.microsoftatlanta-"\
                                      "int.com/ConfigurationService.Svc/RenewCertificate"

  VALID_OMSADMIN_CONF = "WORKSPACE_ID=#{VALID_WORKSPACE_ID}\n"\
                        "AGENT_GUID=#{VALID_AGENT_GUID}\n"\
                        "LOG_FACILITY=local0\n"\
                        "CERTIFICATE_UPDATE_ENDPOINT=#{VALID_CERTIFICATE_UPDATE_ENDPOINT}\n"\
                        "URL_TLD=int2.microsoftatlanta-int.com\n"\
                        "DSC_ENDPOINT=https://oaasagentsvcdf.cloudapp.net/Accounts/"\
                        "#{VALID_WORKSPACE_ID}/Nodes(AgentId='#{VALID_AGENT_GUID}')\n"\
                        "OMS_ENDPOINT=https://#{VALID_WORKSPACE_ID}.ods."\
                        "int2.microsoftatlanta-int.com/OperationalData.svc/PostJsonDataItems\n"\
                        "AZURE_RESOURCE_ID=\n"\
                        "OMSCLOUD_ID=7783-7084-3265-9085-8269-3286-77\n"\
                        "UUID=274E8EF9-2B6F-8A45-801B-AAEE62710796\n"\

  VALID_OS_RELEASE = "OSName=Ubuntu\n"\
                     "OSVersion=18.04\n"\
                     "OSFullName=Ubuntu 18.04 (x86_64)\n"\
                     "OSAlias=UniversalD\n"\
                     "OSManufacturer=Canonical Group Limited\n"\
                     "OSShortName=Ubuntu_18.04\n"\

  DSC_PID = "1"
  OMS_PID = "2"
  PGREP_CMD = "pgrep -U omsagent dsc_host"
  SCX_CMD = "/opt/omi/bin/omicli wql root/scx \"SELECT PercentUserTime, PercentPrivilegedTime, UsedMemory, \
  PercentUsedMemory FROM SCX_UnixProcessStatisticalInformation where Handle='%s'\" | grep ="

  def setup
    @omsadmin_conf_file = Tempfile.new("omsadmin_conf")
    @cert_file = Tempfile.new("oms_crt")
    @key_file = Tempfile.new("oms_key")
    @pid_file = Tempfile.new("omsagent_pid")
    @proxy_file = Tempfile.new("proxy_conf")
    @os_info_file = Tempfile.new("os_info")
    @install_info_file = Tempfile.new("install_info")
    @log = OMS::MockLog.new
  end

  def teardown
    @omsadmin_conf_file.unlink
    @cert_file.unlink
    @key_file.unlink
    @pid_file.unlink
    @proxy_file.unlink
    @os_info_file.unlink
    @install_info_file.unlink
  end

  # Helper to create a new Maintenance class object to test
  def get_new_telemetry_obj(omsadmin_path = @omsadmin_conf_file.path,
       cert_path = @cert_file.path, key_path = @key_file.path, pid_path = @pid_file.path,
       proxy_path = @proxy_file.path, os_info_path = @os_info_file.path,
       install_info_path = @install_info_file.path, log = @log, verbose = false)

    t = OMS::Telemetry.new(omsadmin_path, cert_path, key_path, pid_path,
         proxy_path, os_info_path, install_info_path, log, verbose)
    t.suppress_stdout = true
    return t
  end

  def test_invalid_data
    at  = OMS::AgentTelemetry.new
    aru = OMS::AgentResourceUsage.new
    qos = OMS::AgentQoS.new

    # OSType should be type String
    assert_raise ArgumentError do
      at.OSType = 1
    end

    # AgentResourceUsage should be type AgentResourceUsage
    assert_raise ArgumentError do
      at.AgentResourceUsage = "."
    end

    # AgentQoS should be type Array
    assert_raise ArgumentError do
      at.AgentResourceUsage = "."
    end

    # OMSMaxMemory should be type Integer
    assert_raise ArgumentError do
      aru.OMSMaxMemory = "."
    end

    # Operation should be type String
    assert_raise ArgumentError do
      qos.Operation = 10.0
    end

    # BatchCount should be type Integer
    assert_raise ArgumentError do
      qos.BatchCount = "0"
    end
  end

  def test_serialize
    # File.write(@os_info_file.path, VALID_OS_RELEASE)
    # File.write(@omsadmin_conf_file.path, VALID_OMSADMIN_CONF)

    at  = OMS::AgentTelemetry.new
    aru = OMS::AgentResourceUsage.new
    qos = OMS::AgentQoS.new
    err = OMS::AgentError.new

    aru.OMSMaxMemory = 268021
    aru.OMSMaxPercentMemory = 25
    aru.OMSMaxUserTime = 15
    aru.OMSMaxSystemTime = 4
    aru.OMSAvgMemory = 182136
    aru.OMSAvgPercentMemory = 17
    aru.OMSAvgUserTime = 4
    aru.OMSAvgSystemTime = 2
    aru.OMIMaxMemory = 0
    aru.OMIMaxPercentMemory = 0
    aru.OMIMaxUserTime = 0
    aru.OMIMaxSystemTime = 0
    aru.OMIAvgMemory = 0
    aru.OMIAvgPercentMemory = 0
    aru.OMIAvgUserTime = 0
    aru.OMIAvgSystemTime = 0

    qos.Source = "LINUX_SYSLOGS_BLOB.LOGMANAGEMENT"
    qos.Operation = "SendBatch"
    qos.OperationSuccess = "true"
    qos.Message = ""
    qos.BatchCount = 13
    qos.MinBatchEventCount = 4
    qos.MaxBatchEventCount = 25
    qos.AvgBatchEventCount = 10
    qos.MinEventSize = 101
    qos.MaxEventSize = 393
    qos.AvgEventSize = 165
    qos.MinLocalLatencyInMs = 1920
    qos.MaxLocalLatencyInMs = 59478
    qos.AvgLocalLatencyInMs = 4888
    qos.NetworkLatencyInMs = 29

    err.Message = "Test"
    err.Count = 14

    at.OSType = "Linux"
    at.OSDistro = "Ubuntu"
    at.OSVersion = "18.04"
    at.ProcessorArchitecture = "x86_64"
    at.Region = "OnPremise"
    at.ResourceId = ""
    at.ConfigMgrEnabled = "false"
    at.AgentResourceUsage = aru
    at.AgentQoS = [qos]
    at.AgentError = [err]

    expected_result = '{"OSType":"Linux","OSDistro":"Ubuntu","OSVersion":"18.04","ProcessorArchitecture":"x86_64","Region":"OnPremise","ResourceId":"","ConfigMgrEnabled":"false",' \
                      '"AgentResourceUsage":{"OMSMaxMemory":268021,"OMSMaxPercentMemory":25,"OMSMaxUserTime":15,"OMSMaxSystemTime":4,' \
                      '"OMSAvgMemory":182136,"OMSAvgPercentMemory":17,"OMSAvgUserTime":4,"OMSAvgSystemTime":2,"OMIMaxMemory":0,"OMIMaxPercentMemory":0,' \
                      '"OMIMaxUserTime":0,"OMIMaxSystemTime":0,"OMIAvgMemory":0,"OMIAvgPercentMemory":0,"OMIAvgUserTime":0,"OMIAvgSystemTime":0},' \
                      '"AgentQoS":[{"Source":"LINUX_SYSLOGS_BLOB.LOGMANAGEMENT","Message":"","OperationSuccess":"true","BatchCount":13,' \
                      '"Operation":"SendBatch","MinBatchEventCount":4,"MaxBatchEventCount":25,"AvgBatchEventCount":10,"MinEventSize":101,"MaxEventSize":393,' \
                      '"AvgEventSize":165,"MinLocalLatencyInMs":1920,"MaxLocalLatencyInMs":59478,"AvgLocalLatencyInMs":4888,"NetworkLatencyInMs":29}],"AgentError":[{"Message":"Test","Count":14}]}'

    assert_equal(expected_result, at.serialize, "failed serialization of telemetry request payload")
  end

  def test_array_avg
    array = []
    assert_equal(0, OMS::Telemetry.array_avg(array), "failed to handle empty array")
    array = [1, 2, 3, 4]
    assert_equal(Integer, OMS::Telemetry.array_avg(array).class, "failed to return an Integer")
    assert_equal(2, OMS::Telemetry.array_avg(array), "incorrect average with Integer input")
    array = [0.0001, 112.11, 13.21]
    assert_equal(41, OMS::Telemetry.array_avg(array), "incorrect average with Float input")
  end

  def test_qos
    agent_telemetry = get_new_telemetry_obj
    OMS::Telemetry.clear_qos
    time = 40

    records = {"DataType"=>"LINUX_SYSLOGS_BLOB", "IPName"=>"logmanagement", "DataItems"=>
      [{"ident"=>"CRON", "Timestamp"=>"placeholder", "EventTime"=>"2019-03-20T22:23:01.000Z",
        "Host"=>"hestolz-omstest3-rg", "HostIP"=>"172.16.3.5", "ProcessId"=>"25525", "Facility"=>"cron", "Severity"=>"info",
        "Message"=>"(root) CMD (echo \"hello\" >> /var/log/custom.log)"},
        {"ident"=>"CRON", "Timestamp"=>"placeholder", "EventTime"=>"2019-03-20T22:23:01.000Z",
          "Host"=>"hestolz-omstest3-rg", "HostIP"=>"172.16.3.5", "ProcessId"=>"25526", "Facility"=>"cron", "Severity"=>"info",
          "Message"=>"(root) CMD ([ -f /etc/krb5.keytab ] && [ \\( ! -f /etc/opt/omi/creds/omi.keytab \\) -o " \
          "\\( /etc/krb5.keytab -nt /etc/opt/omi/creds/omi.keytab \\) ] && /opt/omi/bin/support/ktstrip " \
          "/etc/krb5.keytab /etc/opt/omi/creds/omi.keytab >/dev/null 2>&1 || true)"}]}
    records['DataItems'].map { |item| item["Timestamp"] = (Time.now - 60).to_s } # simulate push of batch 60s old
    OMS::Telemetry.push_qos_event(OMS::SEND_BATCH, "true", "", "LINUX_SYSLOGS_BLOB.LOGMANAGEMENT", records, records['DataItems'].size, time)
    records['DataItems'].map { |item| item["Timestamp"] = (Time.now - 30).to_s } # simulate push of batch 30s old
    OMS::Telemetry.push_qos_event(OMS::SEND_BATCH, "true", "", "LINUX_SYSLOGS_BLOB.LOGMANAGEMENT", records, records['DataItems'].size, time)

    records = ["hello","hello"]
    OMS::Telemetry.push_qos_event(OMS::SEND_BATCH, "true", "", "oms.blob.CustomLog.CUSTOM_LOG_BLOB.Custom_Log_CL_eec82c07-3e2a-49da-8e1e-2b3521c9de22.*", records, records.size, time)

    records = {"DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement", "DataItems"=>
               [{"Timestamp"=>"2019-03-20T22:23:38.592Z", "Host"=>"hestolz-omstest3-rg", "ObjectName"=>"Network", "InstanceName"=>"eth0",
                 "Collections"=>[{"CounterName"=>"Total Bytes Transmitted", "Value"=>"2441827497"}]},
                {"Timestamp"=>"2019-03-20T22:23:38.595Z", "Host"=>"hestolz-omstest3-rg", "ObjectName"=>"Processor", "InstanceName"=>"0",
                 "Collections"=>[{"CounterName"=>"% Processor Time", "Value"=>"1"}]}]}
    OMS::Telemetry.push_qos_event(OMS::SEND_BATCH, "true", "", "LINUX_PERF_BLOB.LOGMANAGEMENT", records, records['DataItems'].size, time)

    qos = agent_telemetry.calculate_qos

    assert_equal(3, qos.size, "not all three sources detected")

    syslog = qos.find { |event| event.Source == "LINUX_SYSLOGS_BLOB.LOGMANAGEMENT" }
    custom = qos.find { |event| event.Source == "oms.blob.CustomLog.CUSTOM_LOG_BLOB.Custom_Log_CL_eec82c07-3e2a-49da-8e1e-2b3521c9de22.*" }
    perf   = qos.find { |event| event.Source == "LINUX_PERF_BLOB.LOGMANAGEMENT" }

    assert_not_equal(nil, syslog, "syslog qos event not found")
    assert_not_equal(nil, custom, "syslog qos event not found")
    assert_not_equal(nil, perf, "perf qos event not found")

    assert_equal(OMS::SEND_BATCH, syslog.Operation, "wrong operation parsed")
    assert_equal("true", syslog.OperationSuccess, "wrong operation success parsed")
    assert_equal("", syslog.Message, "wrong operation parsed")
    assert_equal(2, syslog.BatchCount, "wrong batch count parsed")
    assert_equal(2, syslog.MinBatchEventCount, "wrong min event count parsed")
    assert_equal(2, syslog.AvgBatchEventCount, "wrong avg event count parsed")
    assert_equal(7, custom.AvgEventSize, "wrong avg event size parsed")
    assert((syslog.AvgLocalLatencyInMs - 45000).between?(0, 2000), "wrong avg local latency parsed")
    assert_equal(time * 1000, perf.NetworkLatencyInMs, "wrong network latency parsed")
  end

  def test_errors
    agent_telemetry = get_new_telemetry_obj
    OMS::Telemetry.clear_errors

    (0..9).each { OMS::Telemetry.push_error_event("(a) (include) the most numerous log message") }
    (0..5).each { OMS::Telemetry.push_error_event("(b) (include) the second most numerous log message") }
    (0..7).each { OMS::Telemetry.push_error_event("(c) (include) the third most numerous log message") }
    (0..2).each { OMS::Telemetry.push_error_event("(d) (include) the fourth most numerous log message") }
    (0..0).each { OMS::Telemetry.push_error_event("(e) (exclude) the least numerous log message") }
    (0..1).each { OMS::Telemetry.push_error_event("(f) (maybe) the tied fifth most numerous log message") }
    (0..1).each { OMS::Telemetry.push_error_event("(g) (maybe) the tied fifth most numerous log message") }
    (0..4).each { OMS::Telemetry.push_error_event("(a) (include) the most numerous log message") }
    (0..5).each { OMS::Telemetry.push_error_event("(b) (include) the second most numerous log message") }

    errors = agent_telemetry.calculate_errors

    assert_equal(5, errors.size, "fewer than five (the limit) log events found")
    
    assert(errors[0].Message.include?("(a)"), "unexpected most frequent error")
    assert(errors[4].Message.include?("(f)") || errors[4].Message.include?("(g)"), "unexpected least frequent error")
    errors.map { |q| assert(!q.Message.include?("(exclude)"), "unexpected infrequent error included") }
    
    assert_equal(15, errors[0].Count, "incorrect count for most numerous log message")
    assert_equal(12, errors[1].Count, "incorrect count for second most numerous log message")
    assert_equal(2,  errors[4].Count, "incorrect count for fifth most numerous log message")
  end

  # def test_calculate_resource_usage_stopped
  #   flexmock(OMS::AgentTelemetry).new_instances do |instance|
  #     # simulate oms and omi not running
  #     instance.should_receive(:`).with(PGREP_CMD).and_return(DSC_PID)
  #     instance.should_receive(:`).with(SCX_CMD % DSC_PID).and_return("")
  #     instance.should_receive(:`).with(SCX_CMD % OMS_PID).and_return("")
  #   end

  #   agent_telemetry = get_new_telemetry_obj
  #   agent_telemetry.poll_resource_usage
  #   ru = agent_telemetry.calculate_resource_usage

  #   assert_equal(0, ru.OMSMaxMemory, "oms max memory should be zero")
  #   assert_equal(0, ru.OMSMaxUserTime, "oms max user time should be zero")
  #   assert_equal(0, ru.OMIAvgPercentMemory, "omi avg percent memory should be zero")
  #   assert_equal(0, ru.OMIAvgSystemTime, "omi avg system time should be zero")

  #   flexmock(OMS::AgentTelemetry).flexmock_teardown
  # end

  # def test_calculate_resource_usage_running
  #   File.write(@pid_file.path, OMS_PID)
  #   flexmock(OMS::AgentTelemetry).new_instances do |instance|
  #     instance.should_receive(:`).with(PGREP_CMD).and_return(DSC_PID)
  #     instance.should_receive(:`).with(SCX_CMD % DSC_PID).and_return("PercentUserTime=2\n \
  #       PercentPrivilegedTime=0\n UsedMemory=197742\n PercentUsedMemory=19")
  #     instance.should_receive(:`).with(SCX_CMD % OMS_PID).and_return("PercentUserTime=6\n \
  #       PercentPrivilegedTime=1\n UsedMemory=209576\n PercentUsedMemory=21")
  #   end

  #   agent_telemetry = get_new_telemetry_obj

  #   mock = flexmock(agent_telemetry)

  #   agent_telemetry.clear_ru_points
  #   agent_telemetry.poll_resource_usage
  #   ru = agent_telemetry.calculate_resource_usage

  #   assert_equal(209576, ru.OMSMaxMemory, "oms max memory is incorrect")
  #   assert_equal(2, ru.OMSMaxUserTime, "oms max user time is incorrect")
  #   assert_equal(21, ru.OMIAvgPercentMemory, "omi avg percent memory is incorrect")
  #   assert_equal(1, ru.OMIAvgSystemTime, "omi avg system time is incorrect")

  #   flexmock(OMS::AgentTelemetry).flexmock_teardown
  # end

end