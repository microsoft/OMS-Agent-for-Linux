$upgradeOMI = $false; #detect only
$checkScriptPath  = "C:\linux\OMIcheck\omi_check.sh"
$upgradeScriptPath = "C:\linux\OMIcheck\omi_upgrade.sh"

# Get all Azure Subscriptions
$subs = Get-AzSubscription
 
# For each subscription execute to find (and upgrade) omi patch on Linux VMs
foreach ($sub in $subs)
{
    #DEBUG: Limit to one subscription only.
    #if ($sub.Name -eq "Geneva Monitoring Agent - LinuxMdsd")
    #{
        # Set Azure Subscription context    
        Set-AzContext -Subscription $sub.Id
        
        Write-Output "Listing Virutal Machines in subscription '$($sub.Name)'"
        $VMs = Get-AzVM -Status
        $VMsSorted = $VMs | Sort-Object -Property ResourceGroupName
        $PreviousRG = ""
        foreach($VM in $VMs)
        {
            #DEBUG: limit to 1 vm only
            #if ($vm.name -ne "my-testing-vm")
            #{
            #    continue
            #}

            if ($PreviousRG -ne $VM.ResourceGroupName)
            {
                Write-Host "`tResourceGroup: " $VM.ResourceGroupName
                $PreviousRG = $VM.ResourceGroupName
            }

            if ($VM.PowerState -ne "VM running")
            {
                Write-Host -ForegroundColor Gray `t`t $VM.Name " in resource group : VM is not running"
                continue
            }
        
            if ($VM.StorageProfile.OsDisk.OsType.ToString() -ne "Linux")
            {
                Write-Host -ForegroundColor Gray `t`t $VM.Name ": VM is not running Linux OS"
                continue
            }

            $check = Invoke-AzVMRunCommand -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -CommandId 'RunShellScript' -ScriptPath $checkScriptPath
 
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
                        $upgrade = Invoke-AzVMRunCommand -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -CommandId 'RunShellScript' -ScriptPath $upgradeScriptPath
                        Write-Host -ForegroundColor Red `t`t $VM.Name ": OMI package is downloaded and upgraded. " $upgrade.Value.Message
                    }
                }
            }
            else
            {
                Write-Host -ForegroundColor Gray `t`t $VM.Name ": VM has no OMI package"
            }
        }
    #}
}
