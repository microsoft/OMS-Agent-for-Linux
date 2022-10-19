- This tool detects vulnerable OMI installations (< 1.6.9.1) in your subscriptions.

- Review the script and update upgradeOMI accordingly.

- You can run this script from cloud shell in Azure portal or Windows/Linux/MacOS desktop: ./OMIcheck.ps1

- Update Az.Compute modules to the latest and/or your Powershell version.

  > Update-Module -Confirm Az.Compute
  > Get-Module -Name Az.Compute

- It should be run in Powershell and output can be directed to a file such as .\OMIcheck.ps1 > out.txt

- It uses the credentials of the user to list the subscriptions and VMs

- It runs a remote command to detect OMI version, and reports findings.

- Optional flag to install omi 1.6.9.1 is off by default. When set to true,
  > if LinuxDiagnostics or OMSAgentLinux extension is installed, they will be updated.
  > If not, the omi package will be downloaded from github and updated.

- You can run the script back to back more than once for validations.
