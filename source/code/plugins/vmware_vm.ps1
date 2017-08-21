$global:VMResult = @()
Class VMwareVMMetrics {
  $Connect

  VMwareVMMetrics($secret) {
    get-Module -ListAvailable PowerCLI.* | Import-Module
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false > $null
    $secure_string = ConvertTo-SecureString $secret.SecureString -Key (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)
    $creds = New-Object System.Management.Automation.PSCredential ($secret.Username, $secure_string)
    $this.Connect = Connect-VIServer -Server $secret.Server -Credential $creds
  }

  [Void]VirtualMachines () {
    $virtualmachines = Get-VM

    foreach ($vm in $virtualmachines){
      $vmnetwork = Get-NetworkAdapter -VM $vm.Name
      $vmdisk = Get-HardDisk $vm

      $vmresult = @{}
      $vmresult.Add("Type","VM")
      $vmresult.Add("Timestamp",$this.Connect.ExtensionData.ServerClock.ToUniversalTime())
      $vmresult.Add("State",$vm.PowerState.tostring())
      $vmresult.Add("VMID",$vm.ID)
      $vmresult.Add("VMName",$vm.Name)
      $vmresult.Add("VMHostID",$vm.VMHostID)
      $vmresult.Add("IPAddress",$vm.Guest.IPAddress[0])
      $vmresult.Add("CPUCount",$vm.NumCpu)
      $vmresult.Add("OSType",$vm.Guest.OSFullName)
      $vmresult.Add("Network",$vmnetwork.NetworkName)
      $vmresult.Add("NetworkType",$vmnetwork.Type.tostring())
      $vmresult.Add("Computer",$vm.VMHost.Name)
      $vmresult.Add("VMMemoryTotalGB",[math]::Round($vm.MemoryGB,2))
      $vmresult.Add("ProvisionedStorageGB",[math]::Round($vm.ProvisionedSpaceGB,2))
      $vmresult.Add("UsedStorageGB",[math]::Round($vm.UsedSpaceGB,2))
      $vmresult.Add('ResourcePool',$vm.ResourcePool.toString())
      $vmresult.Add('ResourcePoolID',$vm.ResourcePool.Id)
      $vmresult.Add('ToolsInstalled',$vm.Guest.ToolsVersion -ne "")
      $vmresult.Add('SnapshotCount', (Get-SnapShot -VM $vm.Name).count)
      $vmresult.Add('StorageFormat',$vmdisk.StorageFormat.toString())
      $vmresult.Add('StoragePersistence',$vmdisk.Persistence.toString())
      $vmresult.Add('StorageCapacityGB',$vmdisk.CapacityGB)
      $vmresult.Add('StoragePath',$vmdisk.Filename)

      if($vm.VMHost.Parent.Name -ne "host"){
        $vmresult.Add("Cluster",$vm.VMHost.Parent.Name)
      }

      if($vm.Guest.ToolsVersion -ne ""){
        $vmresult.Add('ToolsVersion',$vm.Guest.ToolsVersion)
      }

      $this.StreamMetrics($vmresult)
    }
  }

  StreamMetrics ($result) {
    Invoke-WebRequest -Uri http://127.0.0.1:1515/oms.api.VMwareSolution -Method POST -Body ($result | convertto-json)
  }

  GetMetrics () {
    $this.VirtualMachines()
  }
}

if (Test-Path /var/opt/microsoft/omsagent/state/vmware_secret.csv) {
  $allSecrets = Import-Csv "/var/opt/microsoft/omsagent/state/vmware_secret.csv"
  foreach ($secret in $allSecrets){
    $obj=[VMwareVMMetrics]::New($secret)
    $obj.GetMetrics()
  }
}