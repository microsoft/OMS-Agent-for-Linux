# This script lists the virtual machines in Azure subscriptions of the user,
# and looks for vulnerable OMI packages. The report is grouped by subscription and resource group name.

# Set below flag to true if you want vulnerable OMI to be patched.
# If OMSLinuxAgent is installed, then a minor update will be triggered.
# If OMI is standalone, the latest bits will be installed from Github.
$upgradeOMI = $false; #detect only
$omsVersionGood = "1.13"

# Update these paths accordingly. In cloud shell, the path is usually /home/user_name
$checkScriptPath  = "$PSScriptRoot\omi_check.sh"
$upgradeScriptPath = "$PSScriptRoot\omi_upgrade.sh"

# Get all Azure Subscriptions
Connect-AzAccount #-UseDeviceAuthentication
$subs = Get-AzSubscription

# For each subscription execute to find (and upgrade) OMI on Linux VMs
# TODO: This can be converted to ForEach-Object -Parallel. However, it requires PSh >= 7.1
foreach ($sub in $subs)
{
    #DEBUG: Limit to one subscription only.
    #if ($sub.Name -eq "My subscription name here")
    #{
        # Set Azure Subscription context    
        Set-AzContext -Subscription $sub.Id

        Write-Output "Listing Virutal Machines in subscription '$($sub.Name)'"
        $VMs = Get-AzVM

        $VMsSorted = $VMs | Sort-Object -Property ResourceGroupName
        $PreviousRG = ""
        foreach($VM in $VMs)
        {
            #Get status of each VM to prevent throttling
            $VM = Get-AzVM -Name $VM.Name -Status
            
            #DEBUG: limit to 1 vm only
            #if ($vm.name -ne "my-testing-vm")
            #{
            #    continue
            #}

            # Group VMs by resource groups.
            if ($PreviousRG -ne $VM.ResourceGroupName)
            {
                Write-Host "`tResourceGroup: " $VM.ResourceGroupName
                $PreviousRG = $VM.ResourceGroupName
            }

            # Update only running VMs.
            if ($VM.PowerState -ne "VM running")
            {
                Write-Host -ForegroundColor Gray `t`t $VM.Name " in resource group : VM is not running"
                continue
            }

            # Update Linux only VMs.
            if ($VM.StorageProfile.OsDisk.OsType.ToString() -ne "Linux")
            {
                Write-Host -ForegroundColor Gray `t`t $VM.Name ": VM is not running Linux OS"
                continue
            }

            # TODO: Consider setting timeout. Parameter does not exist, -AsJob is an option for v2.
            $check = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -CommandId 'RunShellScript' -ScriptPath $checkScriptPath

            $split = $check.Value.Message.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
            if ($check.Value.Message.Contains("/opt/omi/bin/omiserver:"))
            {
                $pkgVer = $split[3]
                if($pkgVer -eq "OMI-1.6.8-1")
                {
                    Write-Host -ForegroundColor Green `t`t $VM.Name ": VM has patched OMI version " $pkgVer
                }
                else
                {
                    Write-Host -ForegroundColor Red `t`t $VM.Name ": VM has vulnerable OMI version " $pkgVer
                    if ($upgradeOMI)
                    {
                        # If LAD extension is installed, nudge the Azure Guest Agent to pickup the latest bits. 
                        $VMobj = Get-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name
                        $ladExt = $VMobj.Extensions | where { ($_.Publisher -eq "Microsoft.Azure.Diagnostics" -and $_.VirtualMachineExtensionType -eq "LinuxDiagnostic") }
                        if ($ladExt -ne $null)
                        {
                            if ($ladExt.ProvisioningState -eq "Succeeded")
                            {
                                # Trigger a goal state change for GA.
                                Set-AzVMExtension -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName -Location $VM.Location -Publisher $ladExt.Publisher -Name $ladExt.Name -ExtensionType $ladExt.VirtualMachineExtensionType -TypeHandlerVersion $ladExt.TypeHandlerVersion
                                Write-Host -ForegroundColor Green `t`t $VM.Name ": Set LinuxDiagnostic extension goal state for update"
                                continue;
                            }
                            else
                            {
                                Write-Host -ForegroundColor Gray `t`t $VM.Name ": LinuxDiagnostic extension is not in succeeded state. Skipping."
                            }
                        }

                        # If OMSLinuxAgent is installed, nudge the Azure Guest Agent to pickup the latest bits.
                        $omsExt = $VMobj.Extensions | where { ($_.Publisher -eq "Microsoft.EnterpriseCloud.Monitoring" -and $_.VirtualMachineExtensionType -eq "OmsAgentForLinux") }
                        if ($omsExt -ne $null)
                        {
                            if ($omsExt.ProvisioningState -eq "Succeeded")
                            {
                                # Trigger a goal state change for GA.
                                Set-AzVMExtension -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName -Location $VM.Location -Publisher $omsExt.Publisher -Name $omsExt.Name -ExtensionType $omsExt.VirtualMachineExtensionType -TypeHandlerVersion $omsExt.TypeHandlerVersion
                                Write-Host -ForegroundColor Green `t`t $VM.Name ": Set OMSLinuxAgent extension goal state for update"
                                continue
                            }
                            else
                            {
                                Write-Host -ForegroundColor Gray `t`t $VM.Name ": OMSLinuxAgent extension is not in succeeded state. Skipping."
                            }
                        }

                        # Upgrade standalone OMI if none of the above succeeds.
                        $upgrade = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -CommandId 'RunShellScript' -ScriptPath $upgradeScriptPath
                        Write-Host -ForegroundColor Red `t`t $VM.Name ": Result of OMI package upgrade attempt: " $upgrade.Value.Message
                    }
                }
            }
            else
            {
                Write-Host -ForegroundColor Gray `t`t $VM.Name ": VM has no OMI package"
            }

            #DEBUG:
            #break
        }
    #}
}
