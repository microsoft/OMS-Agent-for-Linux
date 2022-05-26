# Script to Update Vulnerable SCX Package (1.6.9.1)
The following document provides quick information on how to detect vulnerable SCX installations (1.6.9.1) in your subscriptions.

## How to Run

After downloading the files, make sure to review the script and update the [optional variables](#optional-variables) accordingly. After that, you can run this script from cloud shell in Azure portal or Windows/Linux/MacOS desktop: `./SCXcheck.ps1`

Update Az.Compute modules to the latest and/or your Powershell version.

  > Update-Module -Confirm Az.Compute
  > Get-Module -Name Az.Compute

It should be run in Powershell and output can be directed to a file such as `.\SCXcheck.ps1 > out.txt`

## Optional Variables

- *upgradeSCX* - flag to install scx 1.6.9.2, off by default. When set to true, the package will be downloaded from github and updated.
- *testSub* - limit scope to given subscription, off by default. When a subscription name is provided, only VMs/VMSSs in that subscription will be checked.
- *testRg* - limit scope to given resource group, off by default. When a resource group name is provided, only VMs/VMSSs in that resource group will be checked.

## Requirements

This version of the script requires [Powershell version >= 7](https://docs.microsoft.com/en-us/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7?view=powershell-7.1) in order to improve performance via `ForEach-Object -Parallel`.