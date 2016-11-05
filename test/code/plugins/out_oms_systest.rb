require 'fluent/test'
require_relative ENV['BASE_DIR'] + '/source/ext/fluentd/test/helper'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/out_oms'
require_relative 'omstestlib'
require_relative 'out_oms_systestbase'
class OutOMSTest < OutOMSSystemTestBase 

  def test_send_data
    # Onboard to create cert and key
    prep_onboard
    do_onboard

    conf = load_configurations

    tag = 'test'
    d = Fluent::Test::OutputTestDriver.new(Fluent::OutputOMS, tag).configure(conf)

    output = d.instance
    output.start

    # Mock syslog data
    record = {"DataType"=>"LINUX_SYSLOGS_BLOB", "IPName"=>"logmanagement", "DataItems"=>[{"ident"=>"niroy", "Timestamp"=>"2015-10-26T05:11:22Z", "Host"=>"niroy64-cent7x-01", "HostIP"=>"fe80::215:5dff:fe81:4c2f%eth0", "Facility"=>"local0", "Severity"=>"warn", "Message"=>"Hello"}]}
    assert_nothing_raised(RuntimeError, "Failed to send syslog data : '#{$log.logs}'") do
      output.handle_record("oms.syslog.local0.warn", record)
    end

    # Mock perf data
    $log.clear
    record = {"DataType"=>"LINUX_PERF_BLOB", "IPName"=>"LogManagement", "DataItems"=>[{"Timestamp"=>"2015-10-26T05:40:37Z", "Host"=>"niroy64-cent7x-01", "ObjectName"=>"Memory", "InstanceName"=>"Memory", "Collections"=>[{"CounterName"=>"Available MBytes Memory", "Value"=>"564"}, {"CounterName"=>"% Available Memory", "Value"=>"28"}, {"CounterName"=>"Used Memory MBytes", "Value"=>"1417"}, {"CounterName"=>"% Used Memory", "Value"=>"72"}, {"CounterName"=>"Pages/sec", "Value"=>"3"}, {"CounterName"=>"Page Reads/sec", "Value"=>"1"}, {"CounterName"=>"Page Writes/sec", "Value"=>"2"}, {"CounterName"=>"Available MBytes Swap", "Value"=>"1931"}, {"CounterName"=>"% Available Swap Space", "Value"=>"94"}, {"CounterName"=>"Used MBytes Swap Space", "Value"=>"116"}, {"CounterName"=>"% Used Swap Space", "Value"=>"6"}]}]}
    assert(output.handle_record("oms.omi", record), "Failed to send perf data : '#{$log.logs}'")

    # Mock zabbix data
    $log.clear
    record =  {"DataType"=>"LINUX_ZABBIXALERTS_BLOB", "IPName"=>"AlertManagement", "DataItems"=>[{"triggerid": "13498","expression": "{13252}>0","description": "Disk I/O is overloaded on Zabbix server","url": "","status": "0","value": "1","priority": "2","lastchange": "1444934001","comments": "OS spends significant time waiting for I/O (input/output) operations. It could be indicator of performance issues with storage system.","error": "","templateid": "13243","type": "0","state": "0","flags": "0","hostname": "Zabbix server","host": "Zabbix server","hostid": "10084","value_flags": "0"}, {"triggerid": "13595","expression": "{13198}=1","description": "Zabbix agent on zabbix-client-3 is unreachable for 5 minutes","url": "","status": "0","value": "1","priority": "3","lastchange": "1442391060","comments": "","error": "","templateid": "10047","type": "0","state": "0","flags": "0","hostname": "zabbix-client-3","host": "zabbix-client-3","hostid": "10107","value_flags": "0"}]}
    assert(output.handle_record("oms.zabbix", record), "Failed to send zabbix data : '#{$log.logs}'")

    # Mock Nagios data
    $log.clear
    record = {"DataType"=>"LINUX_NAGIOSALERTS_BLOB", "IPName"=>"AlertManagement", "DataItems"=>[{"Timestamp"=>"1970-01-01T00:00:00+00:00", "AlertName"=>"SERVICE ALERT", "HostName"=>"host100", "State"=>"alert state", "StateType"=>"state type", "AlertPriority"=>0, "AlertDescription"=>"Alert Description."}]}
    assert(output.handle_record("oms.nagios", record), "Failed to send nagios data : '#{$log.logs}'")
    
    # Mock Linux Updates data
    $log.clear
    record = {"DataType"=>"LINUX_UPDATES_SNAPSHOT_BLOB", "IPName"=>"Updates", "DataItems"=>{"DataItems"=> [{"Collections"=> [{"CollectionName"=>"dpkg_1.18.4ubuntu1.1_Ubuntu 16.04 (x86_64)", "Installed"=>false, "PackageName"=>"dpkg", "PackageVersion"=>"1.18.4ubuntu1.1", "Repository"=>"Ubuntu:16.04/xenial-updates", "Timestamp"=>"1970-01-01T00:00:00.000Z"}], "Computer"=>"HostName","OSFullName"=>"Ubuntu 16.04 (x86_64)", "OSName"=>"Ubuntu", "OSType"=>"Linux", "OSVersion"=>"16.04", "Timestamp"=>"2016-03-15T19:02:38.577Z"}]}}
    assert(output.handle_record("oms.patch_management", record), "Failed to send linux updates data : '#{$log.logs}'")

   $log.clear
   record = {
              "DataType"=>"CONFIG_CHANGE_BLOB",
              "IPName"=>"changetracking",
              "DataItems"=>[
                {
                    "Timestamp" => "2016-08-20T18:12:22.000Z",
                    "Computer" => "host",
                    "ConfigChangeType"=> "Software.Packages",
                    "Collections"=> []
                },
                {
                    "Timestamp" => "2016-08-20T18:12:22.000Z",
                    "Computer" => "host",
                    "ConfigChangeType"=> "Daemons",
                    "Collections"=> [] 
                },
                {
                    "Timestamp" => "2016-08-20T18:12:22.000Z",
                    "Computer" => "host",
                    "ConfigChangeType"=> "Files",
                    "Collections"=> 
		             [{"CollectionName"=>"/etc/yum.conf",
		               "Contents"=>"",
		               "DateCreated"=>"2016-08-20T18:12:22.000Z",
		               "DateModified"=>"2016-08-20T18:12:22.000Z",
		               "FileSystemPath"=>"/etc/yum.conf",
		               "Group"=>"root",
		               "Mode"=>"644",
		               "Owner"=>"root",
		               "Size"=>"835"}]
                }
              ]
            }

    assert(output.handle_record("oms.changetracking", record), "Failed to send change tracking updates data : '#{$log.logs}'")

    $log.clear
    
    record = 
    {
      "DataType"=>"UPDATES_RUN_PROGRESS_BLOB", 
      "IPName"=>"Updates", 
      "DataItems"=>
      [
        {
          "OSType"=>"Linux",
          "Computer"=>"ShujunLinux1", 
          "UpdateRunName"=>"Shujun_Fake_Update_Run_Name1", 
          "UpdateTitle"=>"cairo-dock-data:amd64 (3.4.1-0ubuntu1, automatic)", 
          "UpdateId"=>"d0228460-fd73-43f7-97d9-2df3e18b4fff", 
          "Status"=>"Succeeded", 
          "TimeStamp"=>"2016-10-24T21:54:30.979Z",
          "StartTime"=>"2016-10-21 04:25:51Z",
          "EndTime"=>"2016-10-21 04:30:02Z"
        }, 
        {
          "OSType"=>"Linux",
          "Computer"=>"ShujunLinux2", 
          "UpdateRunName"=>"Shujun_Fake_Update_Run_Name1", 
          "UpdateTitle"=>"cairo-dock-data:amd64 (3.4.1-0ubuntu1, automatic)", 
          "UpdateId"=>"d0228460-fd73-43f7-97d9-2df3e18b4fff", 
          "Status"=>"Succeeded", 
          "TimeStamp"=>"2016-10-24T21:54:30.979Z",
          "StartTime"=>"2016-10-21 04:25:51Z",
          "EndTime"=>"2016-10-21 04:30:02Z"
        }
      ]
    }                                                                                                                                        

    assert(output.handle_record("oms.update_progress", record), "Failed to send update progress data: '#{$log.logs}'")
  end

end
