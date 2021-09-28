param(
    # path to directory containing scripts omi_check.sh and omi_upgrade.sh
    [Parameter(Mandatory=$true)]
    [String] $ScriptPath
)
# Connect-AzAccount #-UseDeviceAuthentication
# $subs = Get-AzSubscription

$upgradeOMI = $false; #detect only
$omsVersionGood = "1.13"

# Update these paths accordingly. In cloud shell, the path is usually /home/user_name
$checkScriptPath  = "$ScriptPath\omi_check.sh"
$upgradeScriptPath = "$ScriptPath\omi_upgrade.sh"

Write-Output $checkScriptPath

# Get all Azure Subscriptions
Connect-AzAccount #-UseDeviceAuthentication
$subs = Get-AzSubscription

# For each subscription execute to find (and upgrade) OMI on Linux VMs
# TODO: This can be converted to ForEach-Object -Parallel. However, it requires PSh >= 7.1
foreach ($sub in $subs)
{
    #DEBUG: Limit to one subscription only.
    if ($sub.Name -eq "DEVOPS")
    {
        # Set Azure Subscription context
        Set-AzContext -Subscription $sub.Id

        Write-Output "Listing ScaleSets in subscription '$($sub.Name)'"
        $scalesets = Get-AzVmss
        foreach($ss in $scalesets)
        {
            Write-Output `t"Listing Instances in ScaleSet $($ss.Name)"
            $instances = Get-AzVmssVM -ResourceGroupName $ss.ResourceGroupName -VMScaleSetName $ss.Name

            foreach($instance in $instances)
            {
                $vmi = Get-AzVmssVM -ResourceGroupName $ss.ResourceGroupName -VMScaleSetName $ss.Name -InstanceId $instance.InstanceId -InstanceView
                $vm = Get-AzVmssVM -ResourceGroupName $ss.ResourceGroupName -VMScaleSetName $ss.Name -InstanceId $instance.InstanceId

                # Update only running VMs.
                if ($vmi.Statuses[$vmi.Statuses.Count - 1].DisplayStatus -ne "VM Running")
                {
                    Write-Host -ForegroundColor Gray `t`t $vm.Name " in resource group : VM is not running"
                    continue
                }

                # Update Linux only VMs.
                if ($vm.StorageProfile.OsDisk.OsType.ToString() -ne "Linux")
                {
                    Write-Host -ForegroundColor Gray `t`t $vm.Name ": VM is not running Linux OS"
                    continue
                }

                $check = Invoke-AzVmssVMRunCommand -VirtualMachineScaleSetVM $VM -CommandId 'RunShellScript' -ScriptPath $checkScriptPath

                $split = $check.Value.Message.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
                if ($check.Value.Message.Contains("/opt/omi/bin/omiserver:"))
                {
                    $pkgVer = $split[3]
                    if($pkgVer -eq "OMI-1.6.8-1")
                    {
                        Write-Host -ForegroundColor Green `t`t $vm.Name ": VM has patched OMI version " $pkgVer
                    }
                    else
                    {
                        Write-Host -ForegroundColor Red `t`t $vm.Name ": VM has vulnerable OMI version " $pkgVer
                        if ($upgradeOMI)
                        {
                            # Is it possible to upgrade similar to how it's done on VM Extension?
                            # E.g. would this work?
                            # $omsExt = $vmi.Extensions | where { ($_.Publisher -eq "Microsoft.EnterpriseCloud.Monitoring" -and $_.Type -eq "OmsAgentForLinux") }
                            # if ($omsExt -ne $null)
                            # {
                                # Trigger a goal state change for GA.
                            #    Add-AzVmssExtension -VirtualMachineScaleSet $ss `
                            #        -Name $omsExt.Name`
                            #        -Publisher $omsExt.Publisher `
                            #        -Type $omsExt.Type
                            #        -TypeHandlerVersion $omsVersionGood -NoWait
                            #    Write-Host -ForegroundColor Green `t`t $vm.Name ": Set OMSLinuxAgent extension goal state for update"
                            #}
                            #else
                            #{

                                # Upgrade standalone OMI.
                                $upgrade = Invoke-AzVmssVMRunCommand -VirtualMachineScaleSetVM $VM -CommandId 'RunShellScript' -ScriptPath $upgradeScriptPath
                                Write-Host -ForegroundColor Red `t`t $vm.Name ": Result of OMI package upgrade attempt: " $upgrade.Value.Message
                            #}
                        }
                    }
                }
                else
                {
                    Write-Host -ForegroundColor Gray `t`t $vm.Name ": VM has no OMI package"
                }

                #DEBUG:
                #break
            }

        }
    }
}