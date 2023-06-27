# This version of the script requires Powershell version >= 7 in order to improve performance via ForEach-Object -Parallel
# https://docs.microsoft.com/en-us/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7?view=powershell-7.1
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires Powershell version 7 or newer to run. Please see https://docs.microsoft.com/en-us/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7?view=powershell-7.1."
    exit 1
}

# This script lists the virtual machines and scale sets in Azure subscriptions of the user,
# and looks for vulnerable OMI packages. The report is grouped by subscription and resource group name.
$ThrottlingLimit = 16
$DEBUG = $false
$LOGDIR = $PSScriptRoot
$logToFile = $true
$logToConsole = $false

# Set below flag to true if you want vulnerable OMI to be patched.
#    - If OMSLinuxAgent or LinuxDiagnostics is installed, then a minor update will be triggered.
#    - OMI package is installed from Github.
$upgradeOMI = $false #detect only

$OmiServerGoodVersion  = "OMI-1.6.10-2"
$OmiPkgGoodVersion     = "1.6.10.2"
$OmsPkgGoodVersion     = "1.14.13-0"
$OmsTypeHandlerVersion = 1.14
$OMSpublisher          = "Microsoft.EnterpriseCloud.Monitoring"
$OMSextName            = "OmsAgentForLinux"
$LADpublisher          = "Microsoft.Azure.Diagnostics"
$LADextName            = "LinuxDiagnostic"
$LadPkgGoodVersion     = "1.5.110-LADmaster.1483"

# Update these paths accordingly. In cloud shell, the path is usually /home/user_name
$checkScriptPath = "$PSScriptRoot/omi_check.sh"
$upgradeScriptPath = "$PSScriptRoot/omi_upgrade.sh"

<#
.DESCRIPTION
    Check two OMI Server Versions
.OUTPUTS
    >0 if $v1 > $v2
    <0 if $v1 < $v2
    0 if $v1 == $v2
#>
function CompareOmiServerVersions($v1, $v2)
{
    if ($using:DEBUG)
    {
        Wait-Debugger
    }

    $reg = 'OMI-(\d+)\.(\d+)\.(\d+)-(\d+)'
    $match = [Regex]::Match($v1, $reg)
    $v1Value = [Int32]::Parse($match.Groups[1].Value) * 1000000000 + [Int32]::Parse($match.Groups[2].Value) * 1000000 + [Int32]::Parse($match.Groups[3].Value) * 1000 + [Int32]::Parse($match.Groups[4].Value)
    $match = [Regex]::Match($v2, $reg)
    $v2Value = [Int32]::Parse($match.Groups[1].Value) * 1000000000 + [Int32]::Parse($match.Groups[2].Value) * 1000000 + [Int32]::Parse($match.Groups[3].Value) * 1000 + [Int32]::Parse($match.Groups[4].Value)
    return $v1Value - $v2Value
}
$CompareOmiServerVersionsFunc = $Function:CompareOmiServerVersions.ToString()

# Parse the response string.
function ParsePkgVersions($str)
{
    if ($using:DEBUG) {
        Wait-Debugger
    }

    if ($null -eq $str)
    {
        return $null
    }

    $splitLines = $str.Split("`n", [System.StringSplitOptions]::RemoveEmptyEntries)

    $omiServerResp   = $splitLines | Where-Object { $_.Contains("/opt/omi/bin/omiserver:") }
    $omiPkgLine      = $splitLines | Where-Object { $_.Contains(" omi ") }
    $ladMdsdPkgLine  = $splitLines | Where-Object { $_.Contains(" lad-mdsd ") }
    $omsAgentPkgLine = $splitLines | Where-Object { $_.Contains(" omsagent ") }
    if ($null -ne $omiServerResp -and $omiServerResp.Length -gt 0)
    {
        $split = $omiServerResp.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
        $omiVer = $split[1]

        if ($null -ne $omiPkgLine)
        {
            $split = $omiPkgLine.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
            $omiPkgVer = $split[2]
        }

        if ($null -ne $ladMdsdPkgLine)
        {
            $split = $ladMdsdPkgLine.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
            $ladMdsdPkgVer = $split[2]
        }

        if ($null -ne $omsAgentPkgLine)
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
$ParsePkgVersionsFunc = $Function:ParsePkgVersions.ToString()

# Get the versions of the packages from a VM.
function IsVMVulnerableOMI($VMorVMssObj, $checkScriptPath, $isVMss, $InstanceId)
{
    if ($using:DEBUG) {
        Wait-Debugger
    }

    if ($isVMss) {
        $VMss = $VMorVMssObj
        $check = Invoke-AzVmssVMRunCommand -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName $VMss.Name -InstanceId $InstanceId -CommandId 'RunShellScript' -ScriptPath $checkScriptPath
    }
    else {
        $VM = $VMorVMssObj
        $check = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -CommandId 'RunShellScript' -ScriptPath $checkScriptPath
    }
    return ParsePkgVersions($check.Value.Message)
}
$IsVMVulnerableOMIFunc = $Function:IsVMVulnerableOMI.ToString()

# If LAD extension is installed, nudge the Azure Guest Agent to pickup the latest bits.
function UpdateLAD($VM, $check, $logger)
{
    if ($using:DEBUG) {
        Wait-Debugger
    }

    if ($check.LadPkgVer -eq $LadPkgGoodVersion)
    {
        return
    }

    $exts = Get-AzVMExtension -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName
    $ladExt = $exts | Where-Object { ($_.Publisher -eq $LADpublisher -and $_.Name -eq $LADextName) }
    if ($null -ne $ladExt)
    {
        if ($ladExt.ProvisioningState -eq "Succeeded")
        {
            # Trigger a goal state change for GA.
            $response = Set-AzVMExtension -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName -Location $ladExt.Location -Publisher $ladExt.Publisher -Name $ladExt.Name -ExtensionType $ladExt.ExtensionType -TypeHandlerVersion $ladExt.TypeHandlerVersion -ForceRerun (Get-Date).ToString()
            if ($response.IsSuccessStatusCode)
            {
                $logger.Log("`t`t" + $VM.Name + ": LinuxDiagnostic extension goal state for update is set.")
            }
            else
            {
                $logger.Log("`t`t" + $VM.Name + ": LinuxDiagnostic extension goal state for update failed to set." + $response)
            }
        }
        else
        {
            $logger.Log("`t`t" + $VM.Name + ": LinuxDiagnostic extension is not in succeeded state. Skipping.")
        }
    }
}
$UpdateLADFunc = $Function:UpdateLAD.ToString()

# If OMSLinuxAgent is installed, nudge the Azure Guest Agent to pickup the latest bits.
Function UpdateOMS($VMorVMssObj, $isVMss, $check, $logger)
{
    if ($using:DEBUG) {
        Wait-Debugger
    }

    if ($check.OmsPkgVer -eq $OmsPkgGoodVersion)
    {
        return
    }

    if ($isVMss)
    {
        $VMss = $VMorVMssObj
        $logger.Log("`t`t" + $VMss.Name + ": VM scale set has vulnerable OMI version " + $check.OmiPkgVer)
        $omsExt = $VMss.VirtualMachineProfile.ExtensionProfile.Extensions | Where-Object { $_.Publisher -eq $OMSpublisher -and $_.Type -eq $OMSextName }
    }
    else
    {
        $VM = $VMorVMssObj
        $exts = Get-AzVMExtension -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName
        $omsExt = $exts | Where-Object { ($_.Publisher -eq $OMSpublisher -and $_.Name -eq $OMSextName) }
    }

    if ($null -ne $omsExt)
    {
        if ($isVMss)
        {
            # Trigger a goal state change for VMSS.
            $omsExt.AutoUpgradeMinorVersion = $true
            $omsExt.TypeHandlerVersion = $OmsTypeHandlerVersion
            $forceUpdateString = (Get-Date).ToString()
            $omsExt.ForceUpdateTag = $forceUpdateString
            $response = Update-AzVmss -VirtualMachineScaleSet $VMss -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName $VMss.Name
            $omsExt2 = $response.VirtualMachineProfile.ExtensionProfile.Extensions | Where-Object { $_.Publisher -eq $OMSpublisher -and $_.Type -eq $OMSextName }
            if ($omsExt2.ForceUpdateTag -eq $forceUpdateString)
            {
                $logger.Log("`t`t" + $VMss.Name + ": OMSLinuxAgent extension goal state for update is set.")
            }
            else
            {
                $logger.Log("`t`t" + $VMss.Name + ": OMSLinuxAgent extension goal state for update failed to set." + $response)
            }
            # If the upgrade policy on the VMSS scale set is manual, start the upgrade on each instance manually.
            if ($VMss.UpgradePolicy.Mode -eq "Manual")
            {
                foreach ($VMinstance in $VMinstances)
                {
                    Update-AzVmssInstance -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName $VMss.Name -InstanceId $VMinstance.InstanceId
                }
            }
            $logger.Log("`t`t" + $VMss.Name + ": Set OMSLinuxAgent extension is updated")
        }
        else
        {
            # Trigger a goal state change for VM.
            if ($omsExt.ProvisioningState -eq "Succeeded")
            {
                # Trigger a goal state change for GA.
                $response = Set-AzVMExtension -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName -Location $omsExt.Location -Publisher $omsExt.Publisher -Name $omsExt.Name -ExtensionType $omsExt.ExtensionType -TypeHandlerVersion $OmsTypeHandlerVersion -ForceRerun (Get-Date).ToString()
                if ($response.IsSuccessStatusCode)
                {
                    $logger.Log("`t`t" + $VM.Name + ": OMSLinuxAgent extension goal state for update is set.")
                }
                else
                {
                    $logger.Log("`t`t" + $VM.Name + ": OMSLinuxAgent extension goal state for update failed to set." + $response)
                }
            }
            else
            {
                $logger.Log("`t`t" + $VM.Name + ": OMSLinuxAgent extension is not in succeeded state. Skipping.")
            }
        }
    }
}
$UpdateOMSFunc = $Function:UpdateOMS.ToString()

# If LAD is installed in VM scale set, nudge the Azure Guest Agent to pickup the latest bits.
function UpdateLADinVMSS($VMss, $logger)
{
    $logger.Log("`t`t" + $VMss.Name + ": VM scale set has vulnerable OMI version " + $pkgVer)

    $ladExt = $VMss.VirtualMachineProfile.ExtensionProfile.Extensions | Where-Object { $_.Publisher -eq $LADpublisher -and $_.Type -eq $LADextName }
    if ($null -ne $ladExt)
    {
        # Trigger a goal state change for GA.
        $ladExt.AutoUpgradeMinorVersion = $true
        $forceUpdateString = (Get-Date).ToString()
        $ladExt.ForceUpdateTag = forceUpdateString
        $response = Update-AzVmss -VirtualMachineScaleSet $VMss -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName $VMss.Name
        $ladExt2 = $VMss.VirtualMachineProfile.ExtensionProfile.Extensions | Where-Object { $_.Publisher -eq $LADpublisher -and $_.Type -eq $LADextName }
        if ($ladExt2.ForceUpdateTag -eq $forceUpdateString)
        {
            $logger.Log("`t`t" + $VMss.Name + ": LinuxDiagnostic extension goal state for update is set.")
        }
        else
        {
            $logger.Log("`t`t" + $VMss.Name + ": LinuxDiagnostic extension goal state for update failed to set." + $response)
        }
        # If the upgrade policy on the VMSS scale set is manual, start the upgrade on each instance manually.
        if ($VMss.UpgradePolicy.Mode -eq "Manual")
        {
            $VMinstances | ForEach-Object -Parallel -ThrottleLimit $ThrottlingLimit
            {
                Update-AzVmssInstance -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName $VMss.Name -InstanceId $_.InstanceId
            }
        }
        $logger.Log("`t`t" + $VMss.Name + ": Set LAD extension is updated")
    }
}

# Upgrade OMI package in VM.
function UpgradeVmOMI($VM, $upgradeScriptPath, $logger)
{
    if ($using:DEBUG) {
        Wait-Debugger
    }

    $upgrade = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -CommandId 'RunShellScript' -ScriptPath $upgradeScriptPath
    $logger.Log("`t`t" + $VM.Name + ": Result of OMI package upgrade attempt: " + $upgrade.Value.Message)
}
$UpgradeVmOMIFunc = $Function:UpgradeVmOMI.ToString()

# Upgrade OMI package in VMSS instance.
function UpgradeVmssOMI($VMss, $InstanceId, $logger)
{
    $upgrade = Invoke-AzVmssVMRunCommand -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName  $VMss.Name -InstanceId $InstanceId -CommandId 'RunShellScript' -ScriptPath $using:upgradeScriptPath
    if ($upgrade.Value.Message.Contains($using:OmiServerGoodVersion))
    {
        $logger.Log("`t`t`t" + $VMss.Name + " instance " + $InstanceId + ": OMI package upgrade successfully.")
    }
    else
    {
        $logger.Log("`t`t`t" + $VMss.Name + " instance " + $InstanceId + ": OMI package upgrade failed." + $upgrade.Value.Message)
    }
}
$UpgradeVmssOMIFunc = $Function:UpgradeVmssOMI.ToString()

# Find if the VMs in running state and has Linux OS.
function IsVMRunning($VM, $isVMss, $logger) {
    if ($using:DEBUG) {
        Wait-Debugger
    }

    if ($isVMss) {
        if ($VM.ProvisioningState -ne "Succeeded") {
            $logger.Log("`t`t" + $VM.Name + ": VMss is not fully provisioned")
            return $false
        }

        return $true
    }
    else
    {
        if ($VM.ProvisioningState -ne 'Succeeded') {
            $logger.Log("`t`t" + $VM.Name + ": VM is not fully provisioned")
            return $false
        }
        if ($VM.PowerState -ne 'VM running') {
            $logger.Log("`t`t" + $VM.Name + ": VM is not running")
            return $false
        }

        return $true
    }
}
$IsVMRunningFunc = $Function:IsVMRunning.ToString()

# Update the VM extensions and OMI package in a subscription.
function UpdateVMs($sub, $logger)
{
    # Set Azure Subscription context
    Set-AzContext -Subscription $sub.Id

    Write-Output "Listing Virtual Machines in subscription '$($sub.Name)'"
    $VMs = Get-AzVM -Status
    $VMsSorted = $VMs | Sort-Object -Property ResourceGroupName
    $VMsSorted | ForEach-Object -ThrottleLimit $using:ThrottlingLimit -Parallel {
        $VM = $_

        #DEBUG: limit to 1 vm only
        #if ($using:DEBUG -and $VM.name -ne "my-testing-vm")
        #{
        #    continue
        #}

        $logger = $using:logger
        $Function:IsVMRunning = $using:IsVMRunningFunc
        $Function:UpdateOMS = $using:UpdateOMSFunc
        $Function:UpdateLAD = $using:UpdateLADFunc
        $Function:UpgradeOMI = $using:UpgradeVmOMIFunc
        $Function:IsVMVulnerableOMI = $using:IsVMVulnerableOMIFunc
        $Function:CompareOmiServerVersions = $using:CompareOmiServerVersionsFunc
        $Function:ParsePkgVersions = $using:ParsePkgVersionsFunc
        $Variable:Debug = $using:DEBUG

        if (!(IsVMRunning $VM $false $logger))
        {
            Write-Host -NoNewline "."
            continue
        }

        if ($_.StorageProfile.OsDisk.OsType.ToString() -ne "Linux")
        {
            $logger.Log("`t`t" + $VM.Name + ": VM is not running Linux OS")
            Write-Host -NoNewline "."
            return $false
        }

        $check = IsVMVulnerableOMI $VM $using:checkScriptPath $false -1
        if ($null -eq $check)
        {
            $logger.Log("`t`tVM " + $VM.Name + " in resource group " + $VM.ResourceGroupName + " has no OMI package. Skipping.")
            Write-Host -NoNewline "."
            continue
        }

        $versionDiff = CompareOmiServerVersions $check.OmiServerVer $using:OmiServerGoodVersion
        if ($versionDiff -ge 0)
        {
            $logger.Log("`t`tVM " + $VM.Name + " in resource group " + $VM.ResourceGroupName + " has patched OMI version " + $check.OmiPkgVer)
            Write-Host -NoNewline "."
            continue
        }

        $logger.Log("`t`tVM " + $VM.Name + " in resource group " + $VM.ResourceGroupName + " has vulnerable OMI version " + $check.OmiPkgVer)
        if ($using:upgradeOMI)
        {
            # Upgrade LAD extension if necessary.
            UpdateLAD $VM $check $logger

            # Upgrade OMS extension if necessary.
            UpdateOMS $VM false $check $logger

            # Force upgrade OMI pkg just in case.
            UpgradeOMI $VM $using:upgradeScriptPath $logger
        }
        Write-Host -NoNewline "."

        #DEBUG:
        #break
    }
}
$UpdateVMsFunc = $Function:UpdateVMs.ToString()

# Update the VM extensions and OMI package in a subscription for VM scale sets.
function UpdateVMss($sub, $logger)
{
    if ($using:DEBUG) {
        Wait-Debugger
    }

    # Set Azure Subscription context
    Set-AzContext -Subscription $sub.Id

    Write-Output "Listing Virtual Machine scale sets in subscription '$($sub.Name)'"
    $VMsss = Get-AzVmss
    $VMsssSorted = $VMsss | Sort-Object -Property ResourceGroupName
    $VMsssSorted | ForEach-Object -ThrottleLimit $using:ThrottlingLimit -Parallel {
        #DEBUG: limit to 1 vmss only
        # if ($_.Name -ne "my-testing-vmss")
        # {
        #     Write-Host -NoNewline "."
        #     continue
        # }

        $logger = $using:logger
        # Update only running VMss.
        if ($_.ProvisioningState -ne "Succeeded")
        {
            $logger.Log("`t`t" + $_.Name + " VMss is not in succeeded state: " + $_.ProvisioningState)
            Write-Host -NoNewline "."
            continue
        }

        $VMinstances = Get-AzVmssVM -ResourceGroupName $_.ResourceGroupName -VMScaleSetName $_.Name -InstanceView
        if ($null -eq $VMinstances -or 0 -eq $VMinstances.Count)
        {
            $logger.Log("`t`t" + $_.Name + " has no VM instance. Skipping.")
            Write-Host -NoNewline "."
            continue
        }

        $logger = $using:logger
        $Function:IsVMRunning = $using:IsVMRunningFunc
        $Function:UpdateOMS = $using:UpdateOMSFunc
        $Function:UpdateLAD = $using:UpdateLADFunc
        $Function:UpgradeOMI = $using:UpgradeVmOMIFunc
        $Function:IsVMVulnerableOMI = $using:IsVMVulnerableOMIFunc
        $Function:CompareOmiServerVersions = $using:CompareOmiServerVersionsFunc
        $Function:ParsePkgVersions = $using:ParsePkgVersionsFunc
        $Function:UpgradeVmssOMI = $using:UpgradeVmssOMIFunc
        $Variable:Debug = $using:DEBUG
        $Variable:upgradeScriptPath = $using:upgradeScriptPath
        $Variable:logFilePath = $using:logFilePath

        if (!(IsVMRunning $VMinstances[0] $true $logger))
        {
            Write-Host -NoNewline "."
            continue
        }

        if ($null -eq $_.VirtualMachineProfile.OsProfile.LinuxConfiguration)
        {
            $logger.Log("`t`t" + $_.Name + " is not running Linux. Skipping.")
            continue
        }

        $check = IsVMVulnerableOMI $_ $using:checkScriptPath $true $VMinstances[0].InstanceId
        if ($null -eq $check)
        {
            $logger.Log("`t`t" + $_.Name + " VMss has no OMI package. Skipping.")
            Write-Host -NoNewline "."
            continue
        }

        $versionDiff = CompareOmiServerVersions $check.OmiServerVer $using:OmiServerGoodVersion
        if ($versionDiff -ge 0)
        {
            $logger.Log("`t`t" + $_.Name + " VMss has patched OMI version " + $check.OmiPkgVer)
            Write-Host -NoNewline "."
            continue
        }

        if ($using:upgradeOMI)
        {
            if ($null -ne $check.LadPkgVer -and $check.LadPkgVer -ne $using:LadPkgGoodVersion)
            {
                UpdateLADinVMSS $_ $logger
            }

            if ($null -ne $check.OmsPkgVer -and $check.OmsPkgVer -ne $using:OmsPkgGoodVersion)
            {
                UpdateOMS $_ true $check $logger
            }

            # Force upgrade OMI pkg in instances just in case.
            foreach ($VMinst in $VMinstances)
            {
                UpgradeVmssOMI $_ $VMinst.InstanceId $logger
            }
        }
        Write-Host -NoNewline "."

        #DEBUG:
        #break
    }
}
$UpdateVMssFunc = $Function:UpdateVMss.ToString()

# For each subscription execute to find (and upgrade) OMI on Linux VMs
function UpdateConnectedMachines($sub, $rg)
{
    # Set Azure Subscription context
    Set-AzContext -Subscription $sub.Id

    Write-Output "Listing connected machines (ARC servers) in subscription '$($sub.Name)'"
    $connectedMachines = Get-AzConnectedMachine
    $CMsSorted = $connectedMachines | Sort-Object -Property ResourceGroupName
    foreach ($CM in $CMsSorted)
    {
        #DEBUG: limit to 1 vm only
        # if ($CM.name -ne "my-test-machine-arc")
        # {
        #     continue
        # }

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
        $omsExt = $exts | Where-Object { $_.Publisher -eq $OMSpublisher -and $_.Name -eq $OMSextName }
        if ($null -eq $omsExt)
        {
            Write-Host -ForegroundColor Gray `t`t $CM.Name ": Server has no OMS package. Skipping. "
            continue
        }

        if ($omsExt.TypeHandlerVersion -eq "1.14.13")
        {
            Write-Host -ForegroundColor Green `t`t $CM.Name ": Server has patched OMS version " $omsExt.TypeHandlerVersion
            continue
        }

        Write-Host -ForegroundColor Red `t`t $CM.Name ": Server has vulnerable OMS version " $omsExt.TypeHandlerVersion
        if ($upgradeOMI)
        {
            #Set-AzConnectedMachineExtension -MachineName $CM.Name -ResourceGroupName $rg -Name $OMSextName -Publisher $OMSpublisher -SubscriptionId $sub -TypeHandlerVersion "1.14.13" -AutoUpgradeMinorVersion -Location $CM.Location
            $extToUpdate = Get-AzConnectedMachineExtension -ResourceGroupName $rg -MachineName $CM.Name -Name $OMSextName
            $extToUpdate.AutoUpgradeMinorVersion = $true
            $extToUpdate.TypeHandlerVersion = "1.14.13"
            $extToUpdate | Update-AzConnectedMachineExtension -MachineName $CM.Name -ResourceGroupName $rg -Name $OMSextName
            #Update-AzConnectedMachineExtension -MachineName $CM.Name -ResourceGroupName $rg -Name $OMSextName -Publisher $OMSpublisher -SubscriptionId $sub -TypeHandlerVersion "1.14.13" -AutoUpgradeMinorVersion
        }

        #DEBUG:
        #break
    }
}


############### Entrypoint #######################

#DEBUG: use cached token for faster inner dev loop.
Connect-AzAccount #-UseDeviceAuthentication

# Get all Azure Subscriptions
$subs = Get-AzSubscription

$subs | ForEach-Object -ThrottleLimit $ThrottlingLimit -Parallel {
    #DEBUG: Limit to 1 subscription only
    # if ($_.Name -ne "My Subscription 1")
    # {
    #     continue
    # }

    # Pass the context variables to the runspaces.
    $Function:UpdateVMs = $using:UpdateVMsFunc
    $Function:UpdateVMss = $using:UpdateVMssFunc
    $Variable:IsVMRunningFunc = $using:IsVMRunningFunc
    $Variable:UpdateOMSFunc = $using:UpdateOMSFunc
    $Variable:UpdateLADFunc = $using:UpdateLADFunc
    $Variable:UpgradeVmOMIFunc = $using:UpgradeVmOMIFunc
    $Variable:IsVMVulnerableOMIFunc = $using:IsVMVulnerableOMIFunc
    $Variable:CompareOmiServerVersionsFunc = $using:CompareOmiServerVersionsFunc
    $Variable:ParsePkgVersionsFunc = $using:ParsePkgVersionsFunc
    $Variable:ThrottlingLimit = $using:ThrottlingLimit
    $Variable:checkScriptPath = $using:checkScriptPath
    $Variable:upgradeScriptPath = $using:upgradeScriptPath
    $Variable:OmiServerGoodVersion = $using:OmiServerGoodVersion
    $Variable:OmiPkgGoodVersion = $using:OmiPkgGoodVersion
    $Variable:OmsPkgGoodVersion = $using:OmsPkgGoodVersion
    $Variable:OmsTypeHandlerVersion = $using:OmsTypeHandlerVersion
    $Variable:OMSpublisher = $using:OMSpublisher
    $Variable:OMSextName = $using:OMSextName
    $Variable:LADpublisher = $using:LADpublisher
    $Variable:LADextName = $using:LADextName
    $Variable:LadPkgGoodVersion = $using:LadPkgGoodVersion
    $Variable:upgradeOMI = $using:upgradeOMI
    $Variable:UpgradeVmssOMIFunc = $using:UpgradeVmssOMIFunc
    $Variable:DEBUG = $using:DEBUG
    $LogFilePath                      = $_.Id + ".log"
    $Variable:LogFilePath = $LogFilePath

    if ($using:DEBUG) {
        Write-Host "DEBUG is true. Please attach a debugger."
        Wait-Debugger
    }

    class Logger {
        hidden Logger($LogFile) {
            $this.mutexLog = new-object System.Threading.Mutex($false,'SomeUniqueName')
            $this.LogFilePath = $using:LOGDIR + "/" + $LogFile
            Remove-Item -Path $this.LogFilePath -Force -ErrorAction Ignore
            New-Item -ItemType File -Path $this.LogFilePath -Force
        }
        hidden $mutexLog
        hidden $LogFilePath
        hidden static $instance

        static [Logger] GetLogger($LogFilePath) {
            if ($null -eq [Logger]::instance) {
                [Logger]::instance = New-Object Logger $LogFilePath
            }

            return [Logger]::instance
        }

        Log($message) {
            $this.mutexLog.WaitOne()
            try {

                if ($using:logToConsole)
                {
                    Write-Host $message
                }

                if ($using:logToFile) {
                    $message | Out-File -FilePath $this.LogFilePath -Encoding ascii -Append
                }
            }
            finally {
                $this.mutexLog.ReleaseMutex()
            }
        }
    }

    Write-Host "Logging to $LogFilePath"
    $logger = [Logger]::GetLogger($LogFilePath)
    $logger.Log("Subscription Id= " + $_.Id + ", name = " + $_.Name)

    UpdateVMs $_ $logger

    UpdateVMss $_ $logger

    ### EXPERIMENTAL ####
    # Connected machines does not have ResourceGroup property. Define here.
    #$resourceGroup = "fican-HybridRP"
    #UpdateConnectedMachines $sub $resourceGroup
}
