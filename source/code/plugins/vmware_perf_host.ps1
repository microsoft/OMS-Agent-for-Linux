$global:PerfHostResult = @()
Class VMwarePerfHost {
  $Connect

  VMwarePerfHost($secret) {
    get-Module -ListAvailable PowerCLI.* | Import-Module
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false > $null
    $secure_string = ConvertTo-SecureString $secret.SecureString -Key (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)
    $creds = New-Object System.Management.Automation.PSCredential ($secret.Username, $secure_string)
    $this.Connect = Connect-VIServer -Server $secret.Server -Credential $creds
  }

  [String]GetParent ($parentdetails) {
    $parent = ""

    if($parentdetails.Name -eq "host"){
      $parent = $parentdetails.Parent.Name
    } else {
      $parent = $parentdetails.Name
    }
    return $parent
  }

  [Void]EsxiHost () {
    $hosts = Get-VMHost

    foreach ($hostdetails in $hosts){
      $viewdata = Get-View -ViewType HostSystem -Filter @{"Name"=$hostdetails.Name}
      $hoststat = Get-Stat -Entity $hostdetails.Name -Stat "disk.write.average","disk.read.average","datastore.totalWriteLatency.average","datastore.totalReadLatency.average","datastore.datastoreIops.average" -MaxSamples 15 -Realtime | group-object "Timestamp"

      $computer = @{"Host" = $viewdata.Name; "ObjectName" = "VMware"; "InstanceName" = $hostdetails.Name + "." + $this.GetParent($hostdetails.Parent)}

      # ESXI Capacity & Perf
      $global:PerfHostResult += $computer + @{ "Collections" = @(
        @{"CounterName" = "Avg % Memory Usage"; "Value" = [math]::Round(($hostdetails.MemoryUsageGB * 100) / $hostdetails.MemoryTotalGB,2)},
        @{"CounterName" = "Avg % CPU Usage"; "Value" = [math]::Round(($hostdetails.CpuUsageMhz * 100) / $hostdetails.CpuTotalMhz,2)},
        @{"CounterName" = "CPU Capacity Mhz"; "Value" = $hostdetails.CpuTotalMhz},
        @{"CounterName" = "Total Memory GB"; "Value" = $hostdetails.MemoryTotalGB})
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

        $global:PerfHostResult += $computer + $hostresult
      }

      $storagedetails = Get-Datastore -VMHost $hostdetails.Name
      $capacity = 0
      $freespace = 0
      foreach ($ds in $storagedetails){
        $dsstat = Get-Stat -Entity $ds.Name -MaxSamples 15 -Realtime -Instance "" | group-object "Timestamp"

        $capacity += $ds.CapacityGB
        $freespace += $ds.FreeSpaceGB

        $global:PerfHostResult += @{"Host" = $viewdata.Name; "ObjectName" = "VMware"; "InstanceName" = $ds.Name + "." + $hostdetails.Name; "Collections" = @(
          @{"CounterName" = "Avg Datastore Capacity GB"; "Value" = [math]::Round($ds.CapacityGB,2)},
          @{"CounterName" = "Avg Datastore Freespace GB"; "Value" = [math]::Round($ds.FreeSpaceGB,2)},
          @{"CounterName" = "Avg % Used Storage"; "Value" = [math]::Round((($ds.CapacityGB - $ds.FreeSpaceGB) * 100 ) / $ds.CapacityGB,2)})
        }
      }

      $global:PerfHostResult += $computer + @{ "Collections" = @(
        @{"CounterName" = "Avg Host Datastore Capacity GB"; "Value" = [math]::Round($capacity,2)},
        @{"CounterName" = "Avg Host Datastore Freespace GB"; "Value" = [math]::Round($freespace,2)},
        @{"CounterName" = "Avg Host % Used Storage"; "Value" = [math]::Round((($capacity - $freespace) * 100 ) / $capacity, 2)})
      } 
      
    }
  }

  GetMetrics () {
    $this.EsxiHost()
  }
}

if (Test-Path /var/opt/microsoft/omsagent/state/vmware_secret.csv) {
  $allSecrets = Import-Csv "/var/opt/microsoft/omsagent/state/vmware_secret.csv"
  foreach ($secret in $allSecrets){
    $obj=[VMwarePerfHost]::New($secret)
    $obj.GetMetrics()
  }

  @{"DataType" = "LINUX_PERF_BLOB"; "IPName" = "LogManagement"; "DataItems" = $global:PerfHostResult} | convertto-json -Depth 5
}