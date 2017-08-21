Class VMwarePerfVm {
  $Connect

  VMwarePerfVm($secret) {
    get-Module -ListAvailable PowerCLI.* | Import-Module
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false > $null
    $secure_string = ConvertTo-SecureString $secret.SecureString -Key (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)
    $creds = New-Object System.Management.Automation.PSCredential ($secret.Username, $secure_string)
    $this.Connect = Connect-VIServer -Server $secret.Server -Credential $creds
  }

  [Void]VirtualMachines () {
    $vms = Get-VM

    foreach ($vm in $vms){
      $result = @()
      $result += (@{ "Host" = $vm.VMHost.Name; "ObjectName" = "VMware"; "InstanceName" = $vm.Name; "Collections" = @(
        @{"CounterName" = "Total VM Memory GB"; "Value" = [math]::Round($vm.MemoryGB,2)},
        @{"CounterName" = "Avg VM % Used Storage"; "Value" = [math]::Round(($vm.UsedSpaceGB * 100 ) / $vm.ProvisionedSpaceGB,2)})
      })

      $vmstat = Get-Stat -Entity $vm.Name -Stat "mem.usage.average","cpu.usage.average","disk.usage.average","net.usage.average","datastore.numberReadAveraged.average","datastore.numberWriteAveraged.average" -MaxSamples 15 -Realtime | group-object "Timestamp"
      #$datacenter = Get-Datacenter -VM $vm.Name

      foreach ($timestat in $vmstat){
        $vmresult = @{}
        $vmresult.Add("Timestamp",([DateTime]$timestat.Name).ToUniversalTime())
        $vmresult.Add("InstanceName",$vm.Name) #TODO $datacenter
        $vmresult.Add("Host",$vm.VMHost.Name)
        $vmresult.Add("ObjectName","VMware")


        $collection = @()
        foreach ($stat in $timestat.Group){
          $counter = @{}
          $counter.Add("Value",$stat.Value)
          if($stat.MetricId -eq "mem.usage.average"){
            $counter.Add("CounterName","Avg VM % Memory Usage")
          } elseif ($stat.MetricId -eq "cpu.usage.average") {
            $counter.Add("CounterName","Avg VM % CPU Usage")
          } elseif ($stat.MetricId -eq "disk.usage.average") {
            $counter.Add("CounterName","Avg VM Disk Usage KB/s")
          } elseif ($stat.MetricId -eq "net.usage.average") {
            $counter.Add("CounterName","Avg VM Network Usage KB/s")
          } elseif ($stat.MetricId -eq "datastore.numberReadAveraged.average") {
            $counter.Add("CounterName","Avg VM Read IOPS")
          } elseif ($stat.MetricId -eq "datastore.numberWriteAveraged.average") {
            $counter.Add("CounterName","Avg VM Write IOPS")
          }
          $collection += $counter
        }
        $vmresult.Add("Collections",$collection)

        $result += ($vmresult)
      }
      $this.StreamMetrics($result)
    }
  }

  StreamMetrics ($result) {
    Invoke-WebRequest -Uri http://127.0.0.1:1515/oms.vm_perf -Method POST -Body (@{"DataType" = "LINUX_PERF_BLOB"; "IPName" = "LogManagement"; "DataItems" = $result} | convertto-json -Depth 5)
  }

  GetMetrics () {
    $this.VirtualMachines()
  }
}

if (Test-Path /var/opt/microsoft/omsagent/state/vmware_secret.csv) {
  $allSecrets = Import-Csv "/var/opt/microsoft/omsagent/state/vmware_secret.csv"
  foreach ($secret in $allSecrets){
    $obj=[VMwarePerfVm]::New($secret)
    $obj.GetMetrics()
  }
}