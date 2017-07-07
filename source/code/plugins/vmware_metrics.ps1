Class VMwareMetrics {
  [Array]$Data
  $Connect
  $Secret

  VMwareMetrics() {
    $this.Secret = Import-Csv "/opt/microsoft/omsagent/bin/vmware_secret.csv"
    get-Module -ListAvailable PowerCLI.* | Import-Module
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false > $null
    $secure_string = ConvertTo-SecureString $this.Secret.SecureString -Key (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)
    $creds = New-Object System.Management.Automation.PSCredential ($this.Secret.Username, $secure_string)
    $this.Connect = Connect-VIServer -Server $this.Secret.Server -Credential $creds
  }

  [Void]VirtualMachines ($vmid, $computer) {
    $vm = Get-VM -Id $vmid
    $vmnetwork = Get-NetworkAdapter -VM $vm.Name
    $vmdisk = Get-HardDisk $vm

    $vmresult = @{}
    $vmresult.Add("Type","VM")
    $vmresult.Add("State",$vm.PowerState.tostring())
    $vmresult.Add("VMID",$vm.ID)
    $vmresult.Add("VMName",$vm.Name)
    $vmresult.Add("VMHostID",$vm.VMHostID)
    $vmresult.Add("IPAddress",$vm.Guest.IPAddress[0])
    $vmresult.Add("CPUCount",$vm.NumCpu)
    $vmresult.Add("OSType",$vm.Guest.OSFullName)
    $vmresult.Add("Network",$vmnetwork.NetworkName)
    $vmresult.Add("NetworkType",$vmnetwork.Type.tostring())
    $vmresult.Add("Computer",$computer)
    $vmresult.Add("VMMemoryTotalSizeGB",[math]::Round($vm.MemoryGB,2))
    $vmresult.Add("ProvisionedStorageGB",[math]::Round($vm.ProvisionedSpaceGB,2))
    $vmresult.Add("UsedStorageGB",[math]::Round($vm.UsedSpaceGB,2))
    $vmresult.Add('ResourcePool',$vm.ResourcePool.toString())
    $vmresult.Add('ResourcePoolId',$vm.ResourcePool.Id)
    $vmresult.Add('ToolsInstalled',$vm.Guest.ToolsVersion -ne "")
    $vmresult.Add('SnapshotCount', (Get-SnapShot -VM $vm.Name).count)
    $vmresult.Add('StorageFormat',$vmdisk.StorageFormat)
    $vmresult.Add('StoragePersistence',$vmdisk.Persistence)
    $vmresult.Add('StorageCapacityGB',$vmdisk.CapacityGB)
    $vmresult.Add('StorageBacking',$vmdisk.Filename)

    if($vm.Guest.ToolsVersion -ne ""){
      $vmresult.Add('ToolsVersion',$vm.Guest.ToolsVersion)
    }

    $this.Data+=$vmresult
  }

  [Void]EsxiHost () {
    $hosts = Get-VMHost

    foreach ($hostdetails in $hosts){
      $storagedetails = Get-Datastore -VMHost $hostdetails.Name
      $cluster = Get-Cluster -VMHost $hostdetails.Name
      $esxcli = Get-EsxCli -VMHost $hostdetails

      $viewdata = Get-View -ViewType HostSystem -Filter @{"Name"=$hostdetails.Name} | Select Name, VM,
        @{N="BIOSVersion";E={$_.Hardware.BiosInfo.BiosVersion}},
        @{N="VMotionEnabled";E={$_.Summary.Config.VmotionEnabled}},
        @{N="BootTime";E={$_.Runtime.BootTime}},
        @{N="VMCount";E={$_.Vm.count}},
        @{N="NICCount";E={$_.Summary.Hardware.NumNics}},
        @{N="StorageDatasetCount";E={$_.Datastore.count}},
        @{N="PhysicalNicCount";E={$_.Config.Network.Pnic.count}},
        @{N="Network";E={$_.Network.Value}},
        @{N="HardwareVendor";E={$_.Hardware.SystemInfo.Vendor}}

      $esxiresult = @{}
      # ESXI Inventory
      $esxiresult.Add("Type","ESXI")
      $esxiresult.Add("Timestamp",$this.Connect.ExtensionData.ServerClock.ToUniversalTime())
      $esxiresult.Add("HostID",$hostdetails.ID)
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

      # ESXI Capacity & Perf
      $esxiresult.Add("HostMemoryTotalGB",$hostdetails.MemoryTotalGB)
      $esxiresult.Add("TotalCPUCapacityMhz",$hostdetails.CpuTotalMhz)
      $capacity = 0
      $freespace = 0
      $store = 1

      foreach ($storage in $storagedetails){
        $capacity += $storage.CapacityGB
        $freespace += $storage.FreeSpaceGB

        $esxiresult.Add("Storage"+$store+"CapacityGB",[math]::Round($storage.CapacityGB,2))
        $esxiresult.Add("Storage"+$store+"AvailablespaceGB",[math]::Round($storage.FreeSpaceGB,2))
        $esxiresult.Add("Storage"+$store+"Filetype",$storage.Type)
        $esxiresult.Add("Storage"+$store+"DatasetName",$storage.Name)
        $store += 1
      }
      $esxiresult.Add("StorageTotalCapacityGB",[math]::Round($capacity,2))
      $esxiresult.Add("StorageTotalAvailablespaceGB",[math]::Round($freespace,2))
      $esxiresult.Add("HostStorageUsagePercentage",(($capacity - $freespace) * 100 ) / $capacity)
      
      $esxiresult.Add("Datacenter",$storagedetails.Datacenter.Name)
      $esxiresult.Add("StorageDatasetCount",$viewdata.StorageDatasetCount)

      if ($this.Secret.Solution -eq "vCenter"){
        $esxiresult.Add("VCenter", $this.Secret.Server)
      } else {
        $esxiresult.Add("VCenter",$hostdetails.ExtensionData.Client.ServiceUrl.Split('/')[2])
      }

      $this.Data+=$esxiresult

      foreach ($vm in $viewdata.Vm){
        $this.VirtualMachines( $vm.tostring(), $viewdata.Name )
      }
    }
  }

  [Array]GetMetrics () {
    $this.EsxiHost()
    return $this.Data
  }
}

if (Test-Path /opt/microsoft/omsagent/bin/vmware_secret.csv) {
  $data=[VMwareMetrics]::New()
  $data.GetMetrics() | convertto-json
}