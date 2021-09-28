# This script lists the virtual machines and scale sets in Azure subscriptions of the user,
# and looks for vulnerable OMI packages. The report is grouped by subscription and resource group name.

# Set below flag to true if you want vulnerable OMI to be patched.
#    - If OMSLinuxAgent or LinuxDiagnostics is installed, then a minor update will be triggered.
#    - OMI package is installed from Github.
$upgradeOMI = $false #detect only

$OmiServerGoodVersion = "OMI-1.6.8-1"
$OmiPkgGoodVersion = "1.6.8.1"
$LadPkgGoodVersion = "1.5.110-LADmaster.1483"
$OmsPkgGoodVersion = "1.13.40.0"
$OmsTypeHandlerVersion = 1.13

$LADpublisher = "Microsoft.Azure.Diagnostics"
$LADextName = "LinuxDiagnostic"
$OMSpublisher = "Microsoft.EnterpriseCloud.Monitoring"
$OMSextName = "OmsAgentForLinux"

# Update these paths accordingly. In cloud shell, the path is usually /home/user_name
$checkScriptPath  = "$PSScriptRoot\omi_check.sh"
$upgradeScriptPath = "$PSScriptRoot\omi_upgrade.sh"

# Parse the response string.
function ParsePkgVersions($str)
{
    $splitLines = $str.Split("`n",[System.StringSplitOptions]::RemoveEmptyEntries)

    $omiServerResp   = $splitLines | where { $_.Contains("/opt/omi/bin/omiserver:") }
    $omiPkgLine      = $splitLines | where { $_.Contains(" omi ") }
    $ladMdsdPkgLine  = $splitLines | where { $_.Contains(" lad-mdsd ") }
    $omsAgentPkgLine = $splitLines | where { $_.Contains(" omsagent ") }
    if ($omiServerResp -ne $null -and $omiServerResp.Length -gt 0)
    {
        $split = $omiServerResp.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
        $omiVer = $split[1]

        if ($omiPkgLine -ne $null)
        {
            $split = $omiPkgLine.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
            $omiPkgVer = $split[2]
        }

        if ($ladMdsdPkgLine -ne $null)
        {
            $split = $ladMdsdPkgLine.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
            $ladMdsdPkgVer = $split[2]
        }

        if ($omsAgentPkgLine -ne $null)
        {
            $split = $omsAgentPkgLine.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
            $omsAgentPkgVer = $split[2]
        }

        $ret = "" | Select-Object -Property OmiServerVer,OmiPkgVer,LadPkgVer,OmsPkgVer
        $ret.OmiServerVer = $omiVer
        $ret.OmiPkgVer = $omiPkgVer
        $ret.LadPkgVer = $ladMdsdPkgVer
        $ret.OmsPkgVer = $omsAgentPkgVer

        return $ret
    }

    return $null
}

# Get the versions of the packages from a VM.
function IsVMVulnerableOMI($VM)
{
    # TODO: Consider setting timeout. Parameter does not exist, -AsJob is an option for v2.
    $check = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -CommandId 'RunShellScript' -ScriptPath $checkScriptPath

    return ParsePkgVersions($check.Value.Message)
}

# Get the versions of the packages from a VMSS instance.
function IsVMssVulnerableOMI($VMss, $vmssInst)
{
    # TODO: Consider setting timeout. Parameter does not exist, -AsJob is an option for v2.
    $check = Invoke-AzVmssVMRunCommand -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName $VMss.Name -InstanceId $vmssInst.InstanceId -CommandId 'RunShellScript' -ScriptPath $checkScriptPath

    return ParsePkgVersions($check.Value.Message)
}

# If LAD extension is installed, nudge the Azure Guest Agent to pickup the latest bits.
function UpdateLAD($VM)
{
    $exts = Get-AzVMExtension -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName
    $ladExt = $exts | where { ($_.Publisher -eq $LADpublisher -and $_.Name -eq $LADextName) }
    if ($ladExt -ne $null)
    {
        if ($ladExt.ProvisioningState -eq "Succeeded")
        {
            # Trigger a goal state change for GA.
            $response = Set-AzVMExtension -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName -Location $ladExt.Location -Publisher $ladExt.Publisher -Name $ladExt.Name -ExtensionType $ladExt.ExtensionType -TypeHandlerVersion $ladExt.TypeHandlerVersion -ForceRerun (Get-Date).ToString()
            if ($response.IsSuccessStatusCode)
            {
                Write-Host -ForegroundColor Green `t`t $VM.Name ": LinuxDiagnostic extension goal state for update is set."
            }
            else
            {
                Write-Host -ForegroundColor Red `t`t $VM.Name ": LinuxDiagnostic extension goal state for update failed to set." $response
            }
        }
        else
        {
            Write-Host -ForegroundColor Gray `t`t $VM.Name ": LinuxDiagnostic extension is not in succeeded state. Skipping."
        }
    }
}

# If OMSLinuxAgent is installed, nudge the Azure Guest Agent to pickup the latest bits.
function UpdateOMS($VM)
{
    $exts = Get-AzVMExtension -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName
    $omsExt = $exts | where { ($_.Publisher -eq $OMSpublisher -and $_.Name -eq $OMSextName) }
    if ($omsExt -ne $null)
    {
        if ($omsExt.ProvisioningState -eq "Succeeded")
        {
            # Trigger a goal state change for GA.
            $response = Set-AzVMExtension -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName -Location $omsExt.Location -Publisher $omsExt.Publisher -Name $omsExt.Name -ExtensionType $omsExt.ExtensionType -TypeHandlerVersion $OmsTypeHandlerVersion -ForceRerun (Get-Date).ToString()
            if ($response.IsSuccessStatusCode)
            {
                Write-Host -ForegroundColor Green `t`t $VM.Name ": OMSLinuxAgent extension goal state for update is set."
            }
            else
            {
                Write-Host -ForegroundColor Red `t`t $VM.Name ": OMSLinuxAgent extension goal state for update failed to set." $response
            }
        }
        else
        {
            Write-Host -ForegroundColor Gray `t`t $VM.Name ": OMSLinuxAgent extension is not in succeeded state. Skipping."
        }
    }
}

# If LAD is installed in VM scale set, nudge the Azure Guest Agent to pickup the latest bits.
function UpdateLADinVMSS($VMss)
{
    Write-Host -ForegroundColor Red `t`t $VMss.Name ": VM scale set has vulnerable OMI version " $pkgVer

    $ladExt = $VMss.VirtualMachineProfile.ExtensionProfile.Extensions | where { $_.Publisher -eq $LADpublisher -and $_.Type -eq $LADextName }
    if ($ladExt -ne $null)
    {
        # Trigger a goal state change for GA.
        $ladExt.AutoUpgradeMinorVersion = $true
        $forceUpdateString = (Get-Date).ToString()
        $ladExt.ForceUpdateTag = forceUpdateString
        $response = Update-AzVmss -VirtualMachineScaleSet $VMss -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName $VMss.Name
        $ladExt2 = $VMss.VirtualMachineProfile.ExtensionProfile.Extensions | where { $_.Publisher -eq $LADpublisher -and $_.Type -eq $LADextName }
        if ($ladExt2.ForceUpdateTag -eq $forceUpdateString)
        {
            Write-Host -ForegroundColor Green `t`t $VMss.Name ": LinuxDiagnostic extension goal state for update is set."
        }
        else
        {
            Write-Host -ForegroundColor Red `t`t $VMss.Name ": LinuxDiagnostic extension goal state for update failed to set." $response
        }
        # If the upgrade policy on the VMSS scale set is manual, start the upgrade on each instance manually.
        if ($VMss.UpgradePolicy.Mode -eq "Manual")
        {
            foreach ($VMinstance in $VMinstances)
            {
                Update-AzVmssInstance -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName $VMss.Name -InstanceId $VMinstance.InstanceId
            }
        }
        Write-Host -ForegroundColor Green `t`t $VMss.Name ": Set LAD extension is updated"
    }
}


# If OMSLinuxAgent is installed in VM scale set, nudge the Azure Guest Agent to pickup the latest bits.
function UpdateOMSinVMSS($VMss)
{
    Write-Host -ForegroundColor Red `t`t $VMss.Name ": VM scale set has vulnerable OMI version " $pkgVer

    $omsExt = $VMss.VirtualMachineProfile.ExtensionProfile.Extensions | where { $_.Publisher -eq $OMSpublisher -and $_.Type -eq $OMSextName }
    if ($omsExt -ne $null)
    {
        # Trigger a goal state change for GA.
        $omsExt.AutoUpgradeMinorVersion = $true
        $omsExt.TypeHandlerVersion = $OmsTypeHandlerVersion
        $forceUpdateString = (Get-Date).ToString()
        $omsExt.ForceUpdateTag = $forceUpdateString
        $response = Update-AzVmss -VirtualMachineScaleSet $VMss -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName $VMss.Name
        $omsExt2 = $response.VirtualMachineProfile.ExtensionProfile.Extensions | where { $_.Publisher -eq $OMSpublisher -and $_.Type -eq $OMSextName }
        if ($omsExt2.ForceUpdateTag -eq $forceUpdateString)
        {
            Write-Host -ForegroundColor Green `t`t $VMss.Name ": OMSLinuxAgent extension goal state for update is set."
        }
        else
        {
            Write-Host -ForegroundColor Red `t`t $VMss.Name ": OMSLinuxAgent extension goal state for update failed to set." $response
        }
        # If the upgrade policy on the VMSS scale set is manual, start the upgrade on each instance manually.
        if ($VMss.UpgradePolicy.Mode -eq "Manual")
        {
            foreach ($VMinstance in $VMinstances)
            {
                Update-AzVmssInstance -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName $VMss.Name -InstanceId $VMinstance.InstanceId
            }
        }
        Write-Host -ForegroundColor Green `t`t $VMss.Name ": Set OMSLinuxAgent extension is updated"
    }
}

# Upgrade OMI package in VM.
function UpgradeVmOMI($VM)
{
    $upgrade = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -CommandId 'RunShellScript' -ScriptPath $upgradeScriptPath
    Write-Host -ForegroundColor Red `t`t $VM.Name ": Result of OMI package upgrade attempt: " $upgrade.Value.Message
}

# Upgrade OMI package in VMSS instance.
function UpgradeVmssOMI($VMss, $InstanceId)
{
    $upgrade = Invoke-AzVmssVMRunCommand -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName  $VMss.Name -InstanceId $InstanceId -CommandId 'RunShellScript' -ScriptPath $upgradeScriptPath
    if ($upgrade.Value.Message.Contains($OmiServerGoodVersion))
    {
        Write-Host -ForegroundColor Green `t`t`t $VMss.Name " instance $InstanceId : OMI package upgrade successfully." 
    }
    else
    {
        Write-Host -ForegroundColor Green `t`t`t $VMss.Name " instance $InstanceId : OMI package upgrade failed." $upgrade.Value.Message
    }
}

# Find if the VMs in running state and has Linux OS.
function IsVMRunningLinux($VM)
{
    $provisioningState = $VM.Statuses | where { $_.Code.StartsWith("ProvisioningState") }
    if ($provisioningState.Code -ne "ProvisioningState/succeeded")
    {
        Write-Host -ForegroundColor Gray `t`t $VM.Name ": VM is not fully provisioned"
        return $false
    }
    $powerState = $VM.Statuses | where { $_.Code.StartsWith("PowerState") }
    if ($powerState.Code -ne "PowerState/running")
    {
        Write-Host -ForegroundColor Gray `t`t $VM.Name ": VM is not running"
        return $false
    }

    if ($VMitem -ne $null -and $VMitem.StorageProfile.OsDisk.OsType.ToString() -ne "Linux")
    {
        Write-Host -ForegroundColor Gray `t`t $VM.Name ": VM is not running Linux OS"
        return $false
    }

    return $true
}

# Update the VM extensions and OMI package in a subscription.
# TODO: This can be converted to ForEach-Object -Parallel. However, it requires PSh >= 7.1
function UpdateVMs($sub)
{
    # Set Azure Subscription context
    Set-AzContext -Subscription $sub.Id

    Write-Output "Listing Virutal Machines in subscription '$($sub.Name)'"
    $VMs = Get-AzVM
    $VMsSorted = $VMs | Sort-Object -Property ResourceGroupName
    $PreviousRG = ""
    foreach($VMitem in $VMs)
    {
        $VM = Get-AzVM -Name $VMitem.Name -ResourceGroupName $VMitem.ResourceGroupName -Status

        # DEBUG: limit to 1 vm only
        #if ($VM.name -ne "my-testing-vm")
        #{
        #    continue
        #}

        # Group VMs by resource groups.
        if ($PreviousRG -ne $VM.ResourceGroupName)
        {
            Write-Host "`tResourceGroup: " $VM.ResourceGroupName
            $PreviousRG = $VM.ResourceGroupName
        }

        if (!(IsVMRunningLinux($VM)))
        {
            continue
        }

        $check = IsVMVulnerableOMI($VM)
        if ($check -eq $null)
        {
            Write-Host -ForegroundColor Gray `t`t $VM.Name ": VM has no OMI package. Skipping. "
            continue
        }

        if ($check.OmiServerVer -eq $OmiServerGoodVersion)
        {
            Write-Host -ForegroundColor Green `t`t $VM.Name ": VM has patched OMI version " $check.OmiPkgVer
            continue
        }

        Write-Host -ForegroundColor Red `t`t $VM.Name ": VM has vulnerable OMI version " $check.OmiPkgVer
        if ($upgradeOMI)
        {
            if ($check.LadPkgVer -ne $LadPkgGoodVersion)
            {
                UpdateLAD($VM)
            }

            if ($check.OmsPkgVer -ne $OmsPkgGoodVersion)
            {
                UpdateOMS($VM)
            }

            # Force upgrade OMI pkg just in case.
            UpgradeVmOMI($VM)
        }

        # DEBUG:
        #break
    }
}

# Update the VM extensions and OMI package in a subscription for VM scale sets.
# TODO: This can be converted to ForEach-Object -Parallel. However, it requires PSh >= 7.1
function UpdateVMss($sub)
{
    # Set Azure Subscription context
    Set-AzContext -Subscription $sub.Id

    Write-Output "Listing Virutal Machine scale sets in subscription '$($sub.Name)'"
    $VMsss = Get-AzVmss
    $VMsssSorted = $VMsss | Sort-Object -Property ResourceGroupName
    $PreviousRG = ""
    foreach($VMss in $VMsss)
    {
        # DEBUG: limit to 1 vmss only
        #if ($VMss.name -ne "my-testing-vmss")
        #{
        #    continue
        #}

        # Group VMss by resource groups.
        if ($PreviousRG -ne $VMss.ResourceGroupName)
        {
            Write-Host "`tResourceGroup: " $VMss.ResourceGroupName
            $PreviousRG = $VMss.ResourceGroupName
        }

        # Update only running VMss.
        if ($VMss.ProvisioningState -ne "Succeeded")
        {
            Write-Host -ForegroundColor Gray `t`t $VMss.Name " VMss is not in succeeded state: " $VMss.ProvisioningState
            continue
        }

        $VMinstances = Get-AzVmssVM -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName $VMss.Name -InstanceView
        if (!(IsVMRunningLinux($VMinstances[0].InstanceView)))
        {
            continue
        }
        if ($VMss.VirtualMachineProfile.OsProfile.LinuxConfiguration -eq $null)
        {
            Write-Host -ForegroundColor Gray `t`t $VMss.Name " is not running Linux. Skipping."
            continue
        }

        $check = IsVMssVulnerableOMI $VMss $VMinstances[0]
        if ($check -eq $null)
        {
            Write-Host -ForegroundColor Gray `t`t $VMss.Name ": VMss has no OMI package. Skipping. "
            continue
        }

        if ($check.OmiServerVer -eq $OmiServerGoodVersion)
        {
            Write-Host -ForegroundColor Green `t`t $VMss.Name ": VMss has patched OMI version " $check.OmiPkgVer
            continue
        }

        Write-Host -ForegroundColor Red `t`t $VMss.Name ": VMss has vulnerable OMI version " $check.OmiPkgVer
        if ($upgradeOMI)
        {
            if ($check.LadPkgVer -ne $null -and $check.LadPkgVer -ne $LadPkgGoodVersion)
            {
                UpdateLADinVMSS($VMss)
            }

            if ($check.OmsPkgVer -ne $null -and $check.OmsPkgVer -ne $OmsPkgGoodVersion)
            {
                UpdateOMSinVMSS($VMss)
            }

            # Force upgrade OMI pkg in instances just in case.
            foreach ($VMinst in $VMinstances)
            {
                UpgradeVmssOMI $VMss $VMinst.InstanceId
            }
        }

        # DEBUG:
        #break
    }
}

# For each subscription execute to find (and upgrade) OMI on Linux VMs
# TODO: This can be converted to ForEach-Object -Parallel. However, it requires PSh >= 7.1
function UpdateConnectedMachines($sub, $rg)
{
    # Set Azure Subscription context
    Set-AzContext -Subscription $sub.Id

    Write-Output "Listing connected machines (ARC servers) in subscription '$($sub.Name)'"
    $connectedMachines = Get-AzConnectedMachine
    $CMsSorted = $connectedMachines | Sort-Object -Property ResourceGroupName
    $PreviousRG = ""
    foreach($CM in $CMsSorted)
    {
        # DEBUG: limit to 1 vm only
        #if ($CM.name -ne "my-testing-arc-machine")
        #{
        #    continue
        #}

        # Group VMs by resource groups.
        #if ($PreviousRG -ne $CM.ResourceGroupName)
        #{
        #    Write-Host "`tResourceGroup: " $CM.ResourceGroupName
        #    $PreviousRG = $CM.ResourceGroupName
        #}
        Write-Host "`tResourceGroup: " $rg

        if ($CM.ProvisioningState -ne "Succeeded")
        {
            Write-Host -ForegroundColor Gray `t`t $CM.Name ": is not provisioned. Skipping. "
            continue
        }

        if ($CM.Status -ne "Connected")
        {
            Write-Host -ForegroundColor Gray `t`t $CM.Name ": is not connected. Skipping. "
            continue
        }

        $exts = Get-AzConnectedMachineExtension -MachineName $CM.Name -ResourceGroupName $rg
        $omsExt = $exts | where { $_.Publisher -eq $OMSpublisher -and $_.Name -eq $OMSextName }
        if ($omsExt -eq $null)
        {
            Write-Host -ForegroundColor Gray `t`t $CM.Name ": Server has no OMS package. Skipping. "
            continue
        }

        if ($omsExt.TypeHandlerVersion -eq "1.13.40")
        {
            Write-Host -ForegroundColor Green `t`t $CM.Name ": Server has patched OMS version " $omsExt.TypeHandlerVersion
            continue
        }

        Write-Host -ForegroundColor Red `t`t $CM.Name ": Server has vulnerable OMS version " $omsExt.TypeHandlerVersion
        if ($upgradeOMI)
        {
            #Set-AzConnectedMachineExtension -MachineName $CM.Name -ResourceGroupName $rg -Name $OMSextName -Publisher $OMSpublisher -SubscriptionId $sub -TypeHandlerVersion "1.13.40" -AutoUpgradeMinorVersion -Location $CM.Location
            $extToUpdate = Get-AzConnectedMachineExtension -ResourceGroupName $rg -MachineName $CM.Name -Name $OMSextName
            $extToUpdate.AutoUpgradeMinorVersion = $true
            $extToUpdate.TypeHandlerVersion = "1.13.40"
            $extToUpdate | Update-AzConnectedMachineExtension -MachineName $CM.Name -ResourceGroupName $rg -Name $OMSextName
            #Update-AzConnectedMachineExtension -MachineName $CM.Name -ResourceGroupName $rg -Name $OMSextName -Publisher $OMSpublisher -SubscriptionId $sub -TypeHandlerVersion "1.13.40" -AutoUpgradeMinorVersion
        }

        # DEBUG:
        #break
    }
}


############### Entrypoint #######################

# Get all Azure Subscriptions
Connect-AzAccount #-UseDeviceAuthentication
$subs = Get-AzSubscription

foreach ($sub in $subs)
{
    # DEBUG: Limit to one subscription only.
    #if ($sub.Name -ne "My-Testing-Subscription-Name")
    #{
    #    continue
    #}

    UpdateVMs($sub)

    UpdateVMss($sub)

    # EXPERIMENTAL
    # Connected machines does not have ResourceGroup property. Define here.
    # $resourceGroup = "fican-HybridRP"
    # UpdateConnectedMachines $sub $resourceGroup
}
