$upgradeOMI = $false; #detect only

$checkScriptPath  = "$($PSScriptRoot)\omi_check.sh"
$upgradeScriptPath = "$($PSScriptRoot)\omi_upgrade.sh"

# Get all Azure Subscriptions
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
                        $upgrade = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -CommandId 'RunShellScript' -ScriptPath $upgradeScriptPath
                        Write-Host -ForegroundColor Red `t`t $VM.Name ": Result of OMI package upgrade attempt: " $upgrade.Value.Message
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