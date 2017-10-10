Class VMwareHostMetrics {
  $Connect
  $Secret

  VMwareHostMetrics($secret) {
    $this.Secret = $secret
    get-Module -ListAvailable PowerCLI.* | Import-Module
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false > $null
    $secure_string = ConvertTo-SecureString $this.Secret.SecureString -Key (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)
    $creds = New-Object System.Management.Automation.PSCredential ($this.Secret.Username, $secure_string)
    $this.Connect = Connect-VIServer -Server $this.Secret.Server -Credential $creds
  }

  [Void]EsxiHost () {
    $hosts = Get-VMHost

    foreach ($hostdetails in $hosts){
      $storagedetails = Get-Datastore -VMHost $hostdetails.Name
      $cluster = Get-Cluster -VMHost $hostdetails.Name
      $esxcli = Get-EsxCli -VMHost $hostdetails
      $datacenter = Get-Datacenter -VMHost $hostdetails.Name

      $viewdata = Get-View -ViewType HostSystem -Filter @{"Name"=$hostdetails.Name} | Select Name, VM,
        @{N="BIOSVersion";E={$_.Hardware.BiosInfo.BiosVersion}},
        @{N="VMotionEnabled";E={$_.Summary.Config.VmotionEnabled}},
        @{N="BootTime";E={$_.Runtime.BootTime}},
        @{N="VMCount";E={$_.Vm.count}},
        @{N="NICCount";E={$_.Summary.Hardware.NumNics}},
        @{N="StorageDatastoreCount";E={$_.Datastore.count}},
        @{N="PhysicalNicCount";E={$_.Config.Network.Pnic.count}},
        @{N="Network";E={$_.Network.Value}},
        @{N="HardwareVendor";E={$_.Hardware.SystemInfo.Vendor}}

      $esxiresult = @{}
      # ESXI Inventory
      $esxiresult.Add("Type","ESXI")
      $esxiresult.Add("Timestamp",$this.Connect.ExtensionData.ServerClock.ToUniversalTime())
      $esxiresult.Add("HostID",$hostdetails.ID)
      $esxiresult.Add("Build",$hostdetails.Build)
      $esxiresult.Add("Network",$viewdata.Network)
      $esxiresult.Add("HostState",$hostdetails.PowerState.tostring())
      $esxiresult.Add("ESXIVersion",$hostdetails.Version)
      $esxiresult.Add("IPAddress",$hostdetails.Name)
      $esxiresult.Add("Computer",$viewdata.Name)
      $esxiresult.Add("CPUCount",$hostdetails.NumCpu)
      $esxiresult.Add("ProcessorType",$hostdetails.ProcessorType)
      $esxiresult.Add("VMCount",$viewdata.VMCount)
      $esxiresult.Add("BIOSVersion",$viewdata.BIOSVersion)
      $esxiresult.Add("VMotionEnabled",$viewdata.VMotionEnabled)
      $esxiresult.Add("BootTime",$viewdata.BootTime)
      $esxiresult.Add("NICCount",$viewdata.NICCount)
      $esxiresult.Add("PhysicalNicCount",$viewdata.PhysicalNicCount)
      $esxiresult.Add("HardwareVendor",$viewdata.HardwareVendor)
      $esxiresult.Add("HostSerialNumber",$esxcli.hardware.platform.get().SerialNumber)

      if($hostdetails.IsStandalone){
        $esxiresult.Add("ServerType","Standalone")
      } else {
        $esxiresult.Add("ServerType","HA")
      }

      if ($cluster){
        $esxiresult.Add("Cluster",$cluster.Name)
      }

      $capacity = 0
      $freespace = 0
      $store = 1

      foreach ($storage in $storagedetails){
        $capacity += $storage.CapacityGB
        $freespace += $storage.FreeSpaceGB

        $storageresult = @{}
        $storageresult.Add("StorageCapacityGB",[math]::Round($storage.CapacityGB,2))
        $storageresult.Add("StorageFreespaceGB",[math]::Round($storage.FreeSpaceGB,2))
        # $storageresult.Add("StorageUsagePercentage",[math]::Round((($storage.CapacityGB - $storage.FreeSpaceGB) * 100 ) / $storage.CapacityGB,2))
        $storageresult.Add("StorageFiletype",$storage.Type)
        $storageresult.Add("StorageDatastoreName",$storage.Name)
        $storageresult.Add("StorageID",$storage.Id)
        $storageresult.Add("StorageState",$storage.State.toString())
        $storageresult.Add("Datacenter",$storage.Datacenter.Name)
        $storageresult.Add("Computer",$viewdata.Name)
        $this.StreamMetrics($storageresult)
      }

      $esxiresult.Add("StorageTotalCapacityGB",[math]::Round($capacity,2))
      $esxiresult.Add("StorageTotalFreespaceGB",[math]::Round($freespace,2))
      # $esxiresult.Add("StorageTotalUsagePercentage",[math]::Round((($capacity - $freespace) * 100 ) / $capacity, 2))
      $esxiresult.Add("StorageDatastoreCount",$viewdata.StorageDatasetCount)

      $esxiresult.Add("Datacenter",$datacenter[0].Name)

      if ($this.Secret.Solution -eq "vCenter"){
        $esxiresult.Add("VCenter", $this.Secret.Server)
      } else {
        $esxiresult.Add("VCenter",$hostdetails.ExtensionData.Client.ServiceUrl.Split('/')[2])
      }

      $this.StreamMetrics($esxiresult)
    }
  }

  StreamMetrics ($result) {
    Invoke-WebRequest -Uri http://127.0.0.1:1515/oms.api.VMwareInventory -Method POST -Body ($result | convertto-json)
  }

  GetMetrics () {
    $this.EsxiHost()
  }
}

if (Test-Path /var/opt/microsoft/omsagent/state/vmware_secret.csv) {
  $allSecrets = Import-Csv "/var/opt/microsoft/omsagent/state/vmware_secret.csv"
  foreach ($secret in $allSecrets){
    $obj=[VMwareHostMetrics]::New($secret)
    $obj.GetMetrics()
  }
}