# This version of the script requires Powershell version >= 7 in order to improve performance via ForEach-Object -Parallel
# https://docs.microsoft.com/en-us/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7?view=powershell-7.1
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires Powershell version 7 or newer to run. Please see https://docs.microsoft.com/en-us/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7?view=powershell-7.1."
    exit 1
}

############### Variables #######################

# This script lists the virtual machines and scale sets in Azure subscriptions of the user,
# and looks for vulnerable SCX packages. The report is grouped by subscription and resource group name.
$ThrottlingLimit = 16
$DEBUG           = $false
$LOGDIR          = $PSScriptRoot
$logToFile       = $true
$logToConsole    = $false

# Set below flag to true if you want vulnerable SCX to be patched.
# SCX package is installed from Github.
$upgradeSCX = $false #detect only

$ScxServerGoodVersion  = "1.6.9-2"
$ScxServerBadVersion   = "1.6.9-1"

# Update these paths accordingly. In cloud shell, the path is usually /home/user_name
$checkScriptPath   = "$PSScriptRoot/scx_check.sh"
$upgradeScriptPath = "$PSScriptRoot/scx_upgrade.sh"

# Update the below variables if you wish to limit the scope to one subscription, or one resource group
# Note that the resource group has to be inside the subscription if using both
$testSub = "" # subscription
$testRg  = "" # resource group


############### Functions #######################

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

    $splitLines = $str.Split("`n",[System.StringSplitOptions]::RemoveEmptyEntries)

    $scxServerResp   = $splitLines | Where-Object { $_.Contains("Version:") }
    if ($null -ne $scxServerResp -and $scxServerResp.Length -gt 0)
    {
        $split = $scxServerResp.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
        $scxVer = $split[1]

        $ret = "" | Select-Object -Property ScxServerVer
        $ret.ScxServerVer = $scxVer

        return $ret
    }

    return $null
}
$ParsePkgVersionsFunc = $Function:ParsePkgVersions.ToString()

# Get the versions of the packages from a VM.
function IsVMVulnerableSCX($VMorVMssObj, $checkScriptPath, $isVMss, $InstanceId)
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
$IsVMVulnerableSCXFunc = $Function:IsVMVulnerableSCX.ToString()

# Upgrade SCX package in VM.
function UpgradeVmSCX($VM, $upgradeScriptPath, $logger)
{
    if ($using:DEBUG) {
        Wait-Debugger
    }

    $upgrade = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -CommandId 'RunShellScript' -ScriptPath $upgradeScriptPath
    $logger.Log("`t`t" + $VM.Name + ": Result of SCX package upgrade attempt: " + $upgrade.Value.Message)
}
$UpgradeVmSCXFunc = $Function:UpgradeVmSCX.ToString()

# Upgrade SCX package in VMSS instance.
function UpgradeVmssSCX($VMss, $InstanceId, $logger)
{
    $upgrade = Invoke-AzVmssVMRunCommand -ResourceGroupName $VMss.ResourceGroupName -VMScaleSetName  $VMss.Name -InstanceId $InstanceId -CommandId 'RunShellScript' -ScriptPath $using:upgradeScriptPath
    if ($upgrade.Value.Message.Contains($using:ScxServerGoodVersion))
    {
        $logger.Log("`t`t`t" + $VMss.Name + " instance " + $InstanceId + ": SCX package upgrade successfully.")
    }
    else
    {
        $logger.Log("`t`t`t" + $VMss.Name + " instance " + $InstanceId + ": SCX package upgrade failed." + $upgrade.Value.Message)
    }
}
$UpgradeVmssSCXFunc = $Function:UpgradeVmssSCX.ToString()

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
    else {
        $provisioningState = $VM.Statuses | Where-Object { $_.Code.StartsWith("ProvisioningState") }
        if ($provisioningState.Code -ne "ProvisioningState/succeeded")
        {
            $logger.Log("`t`t" + $VM.Name + ": VM is not fully provisioned")
            return $false
        }
        $powerState = $VM.Statuses | Where-Object { $_.Code.StartsWith("PowerState") }
        if ($powerState.Code -ne "PowerState/running")
        {
            $logger.Log("`t`t" + $VM.Name + ": VM is not running")
            return $false
        }

        return $true
    }
}
$IsVMRunningFunc = $Function:IsVMRunning.ToString()

# Update the SCX package in a subscription.
function UpdateVMs($sub, $logger)
{
    # Set Azure Subscription context
    Set-AzContext -Subscription $sub.Id

    Write-Output "Listing Virtual Machines in subscription '$($sub.Name)'"
    if ($testRg)
    {
        $VMs = Get-AzVM -ResourceGroupName $using:testRg
    }
    else
    {
        $VMs = Get-AzVM
    }
    
    $VMsSorted = $VMs | Sort-Object -Property ResourceGroupName
    $VMsSorted | ForEach-Object -ThrottleLimit $using:ThrottlingLimit -Parallel {
        $VM = Get-AzVM -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Status

        #DEBUG: limit to 1 vm only
        # if ($VM.name -ne "my-testing-vm")
        # {
        #    continue
        # }

        $logger = $using:logger
        $Function:IsVMRunning       = $using:IsVMRunningFunc
        $Function:UpgradeSCX        = $using:UpgradeVmSCXFunc
        $Function:IsVMVulnerableSCX = $using:IsVMVulnerableSCXFunc
        $Function:ParsePkgVersions  = $using:ParsePkgVersionsFunc
        $Variable:Debug             = $using:DEBUG

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

        $check = IsVMVulnerableSCX $VM $using:checkScriptPath $false -1
        if ($null -eq $check)
        {
            $logger.Log("`t`tVM " + $VM.Name + " in resource group " + $VM.ResourceGroupName + " has no SCX package. Skipping.")
            Write-Host -NoNewline "."
            continue
        }

        if ($check.ScxServerVer -eq $using:ScxServerGoodVersion)
        {
            $logger.Log("`t`tVM " + $VM.Name + " in resource group " + $VM.ResourceGroupName + " has patched SCX version " + $check.ScxServerVer)
            Write-Host -NoNewline "."
            continue
        }

        elseif ($check.ScxServerVer -eq $using:ScxServerBadVersion)
        {   
            $logger.Log("`t`tVM " + $VM.Name + " in resource group " + $VM.ResourceGroupName + " has vulnerable SCX version " + $check.ScxServerVer)
            if ($using:upgradeSCX)
            {
                # Force upgrade SCX pkg.
                UpgradeSCX $VM $using:upgradeScriptPath $logger
            }
            Write-Host -NoNewline "."
            continue
        }

        else
        {
            $logger.Log("`t`tVM " + $VM.Name + " in resource group " + $VM.ResourceGroupName + " has SCX version " + $check.ScxServerVer + " from before the vulnerability. No upgrade necessary.")
            Write-Host -NoNewline "."
            continue
        }

        #DEBUG:
        # break
    }
}
$UpdateVMsFunc = $Function:UpdateVMs.ToString()

# Update the SCX package in a subscription for VM scale sets.
function UpdateVMss($sub, $logger)
{
    if ($using:DEBUG) {
        Wait-Debugger
    }

    # Set Azure Subscription context  
    Set-AzContext -Subscription $sub.Id

    Write-Output "Listing Virutal Machine scale sets in subscription '$($sub.Name)'"
    if ($testRg)
    {
        $VMsss = Get-AzVmss -ResourceGroupName $using:testRg
    }
    else
    {
        $VMsss = Get-AzVmss
    }

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
        $Function:IsVMRunning         = $using:IsVMRunningFunc
        $Function:UpgradeSCX          = $using:UpgradeVmSCXFunc
        $Function:IsVMVulnerableSCX   = $using:IsVMVulnerableSCXFunc
        $Function:ParsePkgVersions    = $using:ParsePkgVersionsFunc
        $Function:UpgradeVmssSCX      = $using:UpgradeVmssSCXFunc
        $Variable:Debug               = $using:DEBUG
        $Variable:upgradeScriptPath   = $using:upgradeScriptPath
        $Variable:logFilePath         = $using:logFilePath

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

        $check = IsVMVulnerableSCX $_ $using:checkScriptPath $true $VMinstances[0].InstanceId
        if ($null -eq $check)
        {
            $logger.Log("`t`t" + $_.Name + " VMss has no SCX package. Skipping.")
            Write-Host -NoNewline "."
            continue
        }

        if ($check.ScxServerVer -eq $using:ScxServerGoodVersion)
        {
            $logger.Log("`t`t" + $_.Name + " VMss has patched SCX version " + $check.ScxServerVer)
            Write-Host -NoNewline "."
            continue
        }

        elseif ($check.ScxServerVer -eq $using:ScxServerBadVersion)
        {
            $logger.Log("`t`tVM " + $VM.Name + " in resource group " + $VM.ResourceGroupName + " has vulnerable SCX version " + $check.ScxServerVer)
            if ($using:upgradeSCX)
            {
                # Force upgrade SCX pkg in instances.
                foreach ($VMinst in $VMinstances)
                {
                    UpgradeVmssSCX $_ $VMinst.InstanceId $logger
                }
            }
            Write-Host -NoNewline "."
            continue
        }

        else
        {
            $logger.Log("`t`t" + $_.Name + " VMss has SCX version " + $check.ScxServerVer + " from before the vulnerability. No upgrade necessary.")
            Write-Host -NoNewline "."
            continue
        }
        #DEBUG:
        # break
    }
}
$UpdateVMssFunc = $Function:UpdateVMss.ToString()



############### Entrypoint #######################

#DEBUG: use cached token for faster inner dev loop.
Connect-AzAccount #-UseDeviceAuthentication

$subs = Get-AzSubscription

$subs | ForEach-Object -ThrottleLimit $ThrottlingLimit -Parallel {

    $Variable:testSub = $using:testSub
    $Variable:testRg  = $using:testRg
    if ( ($testSub) -and ($_.Name -ne $testSub) )
    {
        continue
    }

    # Pass the context variables to the runspaces.
    $Function:UpdateVMs               = $using:UpdateVMsFunc
    $Function:UpdateVMss              = $using:UpdateVMssFunc
    $Variable:IsVMRunningFunc         = $using:IsVMRunningFunc
    $Variable:UpgradeVmSCXFunc        = $using:UpgradeVmSCXFunc
    $Variable:IsVMVulnerableSCXFunc   = $using:IsVMVulnerableSCXFunc
    $Variable:ParsePkgVersionsFunc    = $using:ParsePkgVersionsFunc
    $Variable:ThrottlingLimit         = $using:ThrottlingLimit
    $Variable:checkScriptPath         = $using:checkScriptPath
    $Variable:upgradeScriptPath       = $using:upgradeScriptPath
    $Variable:ScxServerGoodVersion    = $using:ScxServerGoodVersion
    $Variable:ScxServerBadVersion     = $using:ScxServerBadVersion
    $Variable:upgradeSCX              = $using:upgradeSCX
    $Variable:UpgradeVmssSCXFunc      = $using:UpgradeVmssSCXFunc
    $Variable:DEBUG                   = $using:DEBUG
    $LogFilePath                      = $_.Id + ".log"
    $Variable:LogFilePath             = $LogFilePath

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
}
