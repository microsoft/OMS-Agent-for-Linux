- This tool detects vulnerable OMI installations (< 1.6.8.1) in your subscriptions.

- Review the script and update upgradeOMI accordingly.

- It should be run in Powershell and output can be directed to a file such as .\OMIcheck.ps1 > out.txt

- It uses the credentials of the user to list the subscriptions and VMs

- It run a remote command to detect OMI version, and reports findings.

- Optional flag to install omi 1.6.8.1 is off by defualt.