# This script lists the virtual machines in Azure subscriptions of the user,
# and looks for vulnerable OMI packages. The report is grouped by subscription and resource group name.

# Set below flag to true if you want vulnerable OMI to be patched.
# If OMSLinuxAgent is installed, then a minor update will be triggered.
# If OMI is standalone, the latest bits will be installed from Github.
[bool]$upgradeOMI = $false #detect only
[string]$omsVersionGood = "1.13"
[bool]$BlockVMs = $false

# Update these paths accordingly. In cloud shell, the path is usually /home/user_name
$checkScriptPath = "C:\Users\Downloads\omicheck\omisheck.sh"
$upgradeScriptPath = "C:\Users\Downloads\omicheck\omiupgrade.sh"

Clear-Host

# Get all Azure Subscriptions
Connect-AzAccount #-UseDeviceAuthentication
$subs = Get-AzSubscription | Where-Object -Property State -Like "Enabled" | Sort-Object -Property "Name"
Write-Host "`n[OK] $($subs.Count) enabled Subscription/s found!`n" -ForegroundColor Green

# For each subscription execute to find (and upgrade) OMI on Linux VMs
# TODO: This can be converted to ForEach-Object -Parallel. However, it requires PSh >= 7.1

if ($PSVersionTable.PSVersion.Major -ge 7 -and $PSVersionTable.PSVersion.Minor -ge 1) {

    $runAsParallel = Read-Host "Running in Parallel-Mode to improve Performance? (y/n)"

    if ($runAsParallel -Like "y" ) {

        Write-Host  "`n `t*** Running in Parallel-Mode! ***`n" -ForegroundColor Yellow

        $riskyVMs = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()

        $count = 1
        foreach ($sub in $subs) {

            # Set Azure Subscription context
            Write-Host "`n[$count/$($subs.Count)] Switching into Subscription '$($Sub.Name)' ..."
            Set-AzContext -Subscription $sub.Id | Out-Null
            $VMs = Get-AzVM -Status | Where-Object { $_.StorageProfile.OsDisk.OsType -like "Linux" -and $_.ProvisioningState -eq "Succeeded" } | Sort-Object -Property Name

            if ($VMs) {
                Write-Host "[OK] '$($VMs.Count)' Linux-VMs found inside Subscription. Beginning with Analysis ...`n" -ForegroundColor Green
                
                $VMs | ForEach-Object -Parallel {

                    Write-Host "----> '$($_.Name)': Checking VM now ..."

                    # Starting stopped VMs
                    if ($_.PowerState -notlike "VM running") {

                        Write-Host "----> '$($_.Name)': VM is stopped. Starting VM now for Analysis. Please wait ..." -ForegroundColor Yellow
                        Start-AzVM -Name $_.Name -ResourceGroupName $_.ResourceGroupName | Out-Null
                        if ($?) {
                            [bool]$VMwasStopped = $true 
                            Start-Sleep -Seconds 60 # Wait for VM to coming up ...
                            Write-Host "----> '$($VM.Name)': [OK] Starting VM was successful" -ForegroundColor Green
                        }
                    }

                    # Check
                    $check = Invoke-AzVMRunCommand -ResourceGroupName $_.ResourceGroupName -Name $_.Name -CommandId 'RunShellScript' -ScriptPath $using:checkScriptPath
                                  
                    if ($check.Value.Message.Contains("/opt/omi/bin/omiserver:")) {

                        $split = $check.Value.Message.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)  
                        $pkgVer = $split[3]

                        if ($pkgVer -eq "OMI-1.6.8-1") {
                            Write-Host "----> [OK] '$($_.Name)': VM has patched OMI version: $pkgVer" -ForegroundColor Green
                        }
                        else {
                            Write-Host "----> [ERROR] '$($_.Name)': VM has bad OMI version: $pkgVer" -ForegroundColor Red
                            $localRiskyVMs = $using:riskyVMs
                            $localRiskyVMs.Add($_)

                            # Upgrade VM
                            if ($using:upgradeOMI) {

                                {
                                    # If OMSLinuxAgent is installed, nudge the Azure Guest Agent to pickup the latest bits.
                                    $omsExt = $_.Extensions | Where-Object { ($_.Publisher -Like "Microsoft.EnterpriseCloud.Monitoring" -and $_.VirtualMachineExtensionType -Like "OmsAgentForLinux") }
                                    if ($omsExt) {
                                        # Trigger a goal state change for GA.
                                        Set-AzVMExtension -VMName $_.Name -ResourceGroupName $_.ResourceGroupName -Location $_.Location -Publisher $omsExt.Publisher -Name $omsExt.Name -ExtensionType $omsExt.VirtualMachineExtensionType -Version $omsVersionGood -NoWait
                                        Write-Host "----> [OK] '$($_.Name)' Set OMSLinuxAgent extension goal state for update" -ForegroundColor Green
                                    }
                                    else {
                                        # Upgrade standalone OMI.
                                        $upgrade = Invoke-AzVMRunCommand -ResourceGroupName $_.ResourceGroupName -Name $_.Name -CommandId 'RunShellScript' -ScriptPath $using:upgradeScriptPath
                                        Write-Host "----> '$($_.Name)': Result of OMI package upgrade attempt: $upgrade.Value.Message" -ForegroundColor Red
                                    }
                                }
                            }
                        }
                    }
                    else {
                        Write-Host "----> '$($_.Name)': [OK] VM has no OMI package" -ForegroundColor Green
                    }

                    # Stopping running VMs again to save Costs
                    if ($VMwasStopped) {

                        Write-Host "----> '$($_.Name)': [OK] Analysis done! Stopping VM '$($VM.Name)' again ..." -ForegroundColor Green
                        Stop-AzVM -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Force | Out-Null
                    }
                    $count++
                }
            }
            else {
                Write-Host "[OK] No VM found inside Subscription!" -ForegroundColor Green
            }
            $count++
        }
    }
    #Exit
}

Write-Host  "`n `t***Running in Classic-Mode. Minimum Powershell Version7.1 required! ***`n" -ForegroundColor Yellow

### Proceed with regular Code ...
