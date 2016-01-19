# Operations Management Suite (OMS) Agent for Linux Azure VM Extension

Azure VM Extensions are an easy way to deploy dynamic feature sets from Microsoft and other third party providers. 
For additional information about Azure VM Extensions and a list of those available refer to the following [Learn more: Azure Virtual Machine Extensions](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-extensions-features/)

Latest Version of OMS Agent for Linux Extension: **1.0**

The OMS Agent for Linux Extension can:
* Install the OMS Agent for Linux
* Onboard supported Linux VM to an OMS workspace

# User Guide
## 1. Configuration schema
### 1.1. Public configuration
Schema for the public configuration file looks like this:
* `workspaceId`: (required, string) the OMS workspace id to onboard to
```json
{
  "workspaceId": "<workspace-id (guid)>"
}
```
### 1.2. Protected configuration
Schema for the protected configuration file looks like this:
* `workspaceKey`: (required, string) the primary/secondary shared key of the workspace
```json
{
  "workspaceKey": "<workspace-key>"
}
```

## 2. Deploying the OMS Agent for Linux Extension

> **Note:** if you are using Linux Azure Diagnostics the latest version 2.2 is required before installing the Operations Management Suite Agent for Linux. For more information refer to the [Known Limitations section](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/develop/docs/OMS-Agent-for-Linux.md#known-limitations)

You can deploy the OMS Agent for Linux Extension using Azure CLI, Azure Powershell, or an ARM template.

> **Note:** Creating VM in Azure has two deployment model: Classic and [Resource Manager][arm-overview].
In different models, the deploying commands have different syntaxes. Select the right
one in section 2.1 and 2.2 below.
 
### 2.1. Using [**Azure CLI**][azure-cli]
Before deploying OMS Agent for Linux Extension, you should configure your `public.json` and `protected.json` with the respective OMS workspace ID, and OMS workspace key (in section 1.1 and 1.2 above). Both of these properties can be found in the OMS Portal under Settings > Connected Sources.


#### 2.1.1 Classic
The Classic mode is also called Azure Service Management mode. You can change to it by running:
```
$ azure config mode asm
```

You can deploy the OMS Agent for Linux Extension by running:
```
$ azure vm extension set <vm-name> \
OmsAgentForLinux Microsoft.EnterpriseCloud.Monitoring <version> \
--public-config-path public.json  \
--private-config-path protected.json
```

In the command above, you can change version with `'*'` to use latest
version available, or `'1.*'` to get newest version that does not introduce non-
breaking schema changes. To learn the latest version available, run:
```
$ azure vm extension list
```

#### 2.1.2 Resource Manager
You can change to Azure Resource Manager mode by running:
```
$ azure config mode arm
```

You can deploy the OmsAgent Extension by running:
```
$ azure vm extension set <resource-group> <vm-name> \
OmsAgentForLinux Microsoft.EnterpriseCloud.Monitoring <version> \
--public-config-path public.json  \
--private-config-path protected.json
```

> **Note:** In ARM mode, `azure vm extension list` is not available for now.


### 2.2. Using [**Azure Powershell**][azure-powershell]

#### 2.2.1 Classic

You can login to your Azure account (Azure Service Management mode) by running:

```powershell
Add-AzureAccount
```

You can deploy the OmsAgent Extension by running:

```powershell
$VmName = '<vm-name>'
$vm = Get-AzureVM -ServiceName $VmName -Name $VmName

$ExtensionName = 'OmsAgentForLinux'
$Publisher = 'Microsoft.EnterpriseCloud.Monitoring'
$Version = '<version>'

$PublicConf = '{
    "workspaceId": "<workspace id>"
}'
$PrivateConf = '{
    "workspaceKey": "<workspace key>"
}'

Set-AzureVMExtension -ExtensionName $ExtensionName -VM $vm `
  -Publisher $Publisher -Version $Version `
  -PrivateConfiguration $PrivateConf -PublicConfiguration $PublicConf |
  Update-AzureVM
```

#### 2.2.2 Resource Manager

You can login to your Azure account (Azure Resource Manager mode) by running:

```powershell
Login-AzureRmAccount
```

Click [**HERE**](https://azure.microsoft.com/en-us/documentation/articles/powershell-azure-resource-manager/) to learn more about how to use Azure Powershell with Azure Resource Manager.

You can deploy the OmsAgent Extension by running:

```powershell
$RGName = '<resource-group-name>'
$VmName = '<vm-name>'
$Location = '<location>'

$ExtensionName = 'OmsAgentForLinux'
$Publisher = 'Microsoft.EnterpriseCloud.Monitoring'
$Version = '<version>'

$PublicConf = '{
    "workspaceId": "<workspace id>"
}'
$PrivateConf = '{
    "workspaceKey": "<workspace key>"
}'

Set-AzureRmVMExtension -ResourceGroupName $RGName -VMName $VmName -Location $Location `
  -Name $ExtensionName -Publisher $Publisher `
  -ExtensionType $ExtensionName -TypeHandlerVersion $Version `
  -Settingstring $PublicConf -ProtectedSettingString $PrivateConf
```

### 2.3. Using [**ARM Template**][arm-template]
```json
{
  "type": "Microsoft.Compute/virtualMachines/extensions",
  "name": "<extension-deployment-name>",
  "apiVersion": "<api-version>",
  "location": "<location>",
  "dependsOn": [
    "[concat('Microsoft.Compute/virtualMachines/', <vm-name>)]"
  ],
  "properties": {
    "publisher": "Microsoft.EnterpriseCloud.Monitoring",
    "type": "OmsAgentForLinux",
    "typeHandlerVersion": "1.0",
    "settings": {
      "workspaceId": "<workspace id>"
    },
    "protectedSettings": {
      "workspaceKey": "<workspace key>"
    }
  }
}
```

## 3. Scenarios

### 3.1 Onboard to OMS workspace
```json
{
  "workspaceId": "MyWorkspaceId"
}
```
```json
{
  "workspaceKey": "MyWorkspaceKey"
}
```

## Supported Linux Distributions
- CentOS Linux 5,6, and 7 (x86/x64)
- Oracle Linux 5,6, and 7 (x86/x64)
- Red Hat Enterprise Linux Server 5,6 and 7 (x86/x64)
- Debian GNU/Linux 6, 7, and 8 (x86/x64)
- Ubuntu 12.04 LTS, 14.04 LTS, 15.04 (x86/x64)
- SUSE Linux Enterprise Server 11 and 12 (x86/x64)

## Debug

* The status of the extension is reported back to Azure so that user can
see the status on Azure Portal
* All the execution output and errors generated by the extension are logged into
the following directories - 
`/var/lib/waagent/<extension-name-and-version>/packages/`, `/opt/microsoft/omsagent/bin`
and the tail of the output is logged into the log directory specified
in HandlerEnvironment.json and reported back to Azure
* The operation log of the extension is `/var/log/azure/<extension-name>/<version>/extension.log` file.



[azure-powershell]: https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/
[azure-cli]: https://azure.microsoft.com/en-us/documentation/articles/xplat-cli/
[arm-template]: http://azure.microsoft.com/en-us/documentation/templates/ 
[arm-overview]: https://azure.microsoft.com/en-us/documentation/articles/resource-group-overview/
[Set-AzureVMExtension-ARM]: https://msdn.microsoft.com/en-us/library/mt163544.aspx
