Class VMwarePerf {
  [Array]$Data
  $Connect

  VMwarePerf() {
    $secret = Import-Csv "/opt/microsoft/omsagent/bin/vmware_secret.csv"
    get-Module -ListAvailable PowerCLI.* | Import-Module
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false > $null
    $secure_string = ConvertTo-SecureString $secret.SecureString -Key (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)
    $creds = New-Object System.Management.Automation.PSCredential ($secret.Username, $secure_string)
    $this.Connect = Connect-VIServer -Server $secret.Server -Credential $creds
  }

  [Void]VirtualMachines ($vmid, $computer) {
    $vm = Get-VM -Id $vmid
    $vmstat = Get-Stat -Entity $vm.name -Stat "mem.usage.average","cpu.usage.average","disk.usage.average","net.usage.average","datastore.numberReadAveraged.average","datastore.numberWriteAveraged.average" -MaxSamples 15 -Realtime | group-object "Timestamp"

    foreach ($timestat in $vmstat){
      $vmresult = @{}
      $vmresult.Add("Timestamp",([DateTime]$timestat.Name).ToUniversalTime())
      $vmresult.Add("InstanceType","VM")
      $vmresult.Add("InstanceName",$vm.ID)
      $vmresult.Add("Host",$computer)
      $vmresult.Add("ObjectName","VMware")

      $collection = @()
      foreach ($stat in $timestat.Group){
        $counter = @{}
        $counter.Add("Value",$stat.Value)
        if($stat.MetricId -eq "mem.usage.average"){
          $counter.Add("CounterName","Avg % Memory Usage")
        } elseif ($stat.MetricId -eq "cpu.usage.average") {
          $counter.Add("CounterName","Avg % CPU Usage")
        } elseif ($stat.MetricId -eq "disk.usage.average") {
          $counter.Add("CounterName","Avg Disk Usage KB/s")
        } elseif ($stat.MetricId -eq "net.usage.average") {
          $counter.Add("CounterName","Avg Network Usage KB/s")
        } elseif ($stat.MetricId -eq "datastore.numberReadAveraged.average") {
          $counter.Add("CounterName","Avg Read IOPS")
        } elseif ($stat.MetricId -eq "datastore.numberWriteAveraged.average") {
          $counter.Add("CounterName","Avg Write IOPS")
        }
        $collection += $counter
      }
      $vmresult.Add("Collections",$collection)

      $this.Data+=$vmresult
    }
  }

  [Void]EsxiHost () {
    $hostdetails = Get-VMHost
    $viewdata = Get-View -ViewType HostSystem
    $hoststat = Get-Stat -Server $hostdetails.name -Stat "disk.write.average","disk.read.average","datastore.totalWriteLatency.average","datastore.totalReadLatency.average","datastore.datastoreIops.average" -MaxSamples 15 -Realtime | group-object "Timestamp"

    $computer = @{"Host" = $viewdata.Name; "ObjectName" = "VMware"; "InstanceName" = $hostdetails.ID; "InstanceType" = "ESXI"}

    # ESXI Capacity & Perf
    $this.Data += $computer + @{ "Timestamp" = $this.Connect.ExtensionData.ServerClock.ToUniversalTime(); "Collections" = @(
      @{"CounterName" = "% Avg Memory Usage"; "Value" = ($hostdetails.MemoryUsageGB * 100) / $hostdetails.MemoryTotalGB},
      @{"CounterName" = "% Avg CPU Usage"; "Value" = ($hostdetails.CpuUsageMhz * 100) / $hostdetails.CpuTotalMhz})
    }

    foreach ($timestat in $hoststat){
      $hostresult = @{}
      $hostresult.Add("Timestamp",([DateTime]$timestat.Name).ToUniversalTime())

      $collection = @()
      foreach ($stat in $timestat.Group){
        $counter = @{}
        $counter.Add("Value",$stat.Value)
        if($stat.MetricId -eq "disk.write.average"){
          $counter.Add("CounterName","Avg Disk Write KB/s")
        } elseif ($stat.MetricId -eq "disk.read.average") {
          $counter.Add("CounterName","Avg Disk Read KB/s")
        } elseif ($stat.MetricId -eq "datastore.totalWriteLatency.average") {
          $counter.Add("CounterName","Avg Datastore Write Latency ms")
        } elseif ($stat.MetricId -eq "datastore.totalReadLatency.average") {
          $counter.Add("CounterName","Avg Datastore Read Latency ms")
        } elseif ($stat.MetricId -eq "datastore.datastoreIops.average") {
          $counter.Add("CounterName","Avg Datastore IOPS")
        }
        $collection += $counter
      }
      $hostresult.Add("Collections",$collection)

      $this.Data += $computer + $hostresult
    }

    foreach ($vm in $viewdata.Vm){
      $this.VirtualMachines( $vm.tostring(), $viewdata.Name )
    }
  }

  [Array]GetMetrics () {
    $this.EsxiHost()
    return @{"DataType" = "LINUX_PERF_BLOB"; "IPName" = "LogManagement"; "DataItems" = $this.Data}
  }
}

if (Test-Path /opt/microsoft/omsagent/bin/vmware_secret.csv) {
  $data=[VMwarePerf]::New()
  $data.GetMetrics() | convertto-json -Depth 5
}