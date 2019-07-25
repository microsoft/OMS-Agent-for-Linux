
# OMS Extension Automated Testing

## Requirements

* If host machine is Windows:
  * Must active Windows Subsystem for Linux [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
* Create a ssh key using [ssh-keygen](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/)
* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* Putty PSCP
  * [Putty for Windows](https://www.putty.org/)
  * Putty tools for Linux:
    * For DPKG: 'sudo apt-get install putty-tools'
    * For RPM: 'sudo yum install putty-tools'
    * For SUSE: 'sudo zypper install putty-tools'
* Python 2.7+ & [pip](https://pip.pypa.io/en/stable/installing/)
* [Requests](http://docs.python-requests.org/en/master/), [ADAL](https://github.com/AzureAD/azure-activedirectory-library-for-python), [json2html](https://github.com/softvar/json2html), [rstr](https://pypi.org/project/rstr/)

```bash
$ pip install requests adal json2html rstr
```

## Images currently supported for testing:

* CentOS 6 and 7
* Oracle Linux 6 and 7
* Debian 8 and 9
* Ubuntu 14.04, 16.04, and 18.04
* Red Hat 6 and 7
* SUSE 12

## Running Tests

### Prepare

#### Resources

1. Create a resource group that will be used to store all test resources
2. Create an Azure Key Vault to store test secrets
3. Create a Log Analytics workspace where your test VMs will send data
  - From the workspace blade, navigate to Settings > Advanced Settings > and note the workspace Id and Key for later
4. Create a network security group, preferably in West US 2
  - From the NSG blade, navigate to Settings > Inbound Security Rules > Add
  - Use the following settings
    - `Source` – IP Addresses
    - `Source IP Addresses/CIDR ranges` – the IP of your host machine
    - `Source port ranges` – *
    - `Destination` – Any
    - `Destination port ranges` – 22
    - `Protocol` – Any or TCP
    - `Action` – Allow
    - `Priority` – Lowest possible number
    - `Name` – AllowSSH
  - Add
5. [Increase your VM quota](https://docs.microsoft.com/en-us/azure/azure-supportability/resource-manager-core-quotas-request) to 15 in the region you will specify below in parameters.json
6. [Optional] Register your own AAD app to allow end-to-end verification script to access Microsoft REST APIs
  - Azure Portal > Azure Active Directory > App Registrations (Preview) > New Registration
    - `Name` – A name of your choice, can be changed later
    - `Supported Account Types` – Accounts in this organizational directory only (Microsoft)
    - `Redirect URI (Optional)` – Leave blank
    - Register
    - Use Application (client) ID value displayed in app overview to replace `<app-id>` in parameters.json
  - In blade of new registration > Certificates & Secrets > New Client Secret
    - `Description` – A descriptive word or phrase of your choice
    - `Expires` – Never
    - Add
    - *Copy down the new client secret value!* Use this to replace `<app-secret>` in parameters.json

#### Parameters
1. In your Azure Key Vault, manually upload secrets with the following name-value pairings:
  - `<tenant>` – your AAD tenant, visible in Azure Portal > Azure Active Directory > Properties > Directory ID
  - `<app-id>`, `<app-secret>` – verify_e2e service principal ID, secret (available in OneNote document, or use the values from the app you optionally registered in step 6 above)
  - `<subscription-id>` – ID of subscription that hosts your desired Log Analytics test workspace
  - `<tenant-id>` – ID of your Azure AD tenant
  - `<workspace-id>`, `<workspace-key>` – Log Analytics test workspace ID, key  
2. In parameters.json, fill in the following:
  - `<resource group>`, `<location>` – resource group, region (e.g. westus2) in which you want your VMs created
  - `<username>`, `<password>` – the VM username and password (see [requirements](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/faq#what-are-the-password-requirements-when-creating-a-vm))
  - `<nsg resource group>` – resource group of your NSG
  - `<nsg>` – NSG name
  - `<size>` – Standard_B1ms
  - `<workspace>` – name of the workspace you created
  - `<key vault>` – name of the Key Vault you created
  - `<old version>` - specific version of the extension (define as empty "" if not using)

#### Other
1. Allow the end-to-end verification script to read your workspace
  - Open workspace in Azure Portal
  - Access control (IAM) > Add
    - `Role` – Reader
    - `Assign access to` – Azure AD user, group, or application
    - `Select` – verify_e2e
  - Save
2. Log in to Azure using the Azure CLI and set your subscription

```bash
$ az login
$ az account set --subscription subscription_name
```

3. Custom Log Setup:
  - [Custom logs Docs](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-sources-custom-logs)
  - Add custom.log file to setup Custom_Log_CL
    ![AddingCustomlogFile](pictures/AddingCustomlogFile.png?raw=true)
  - Add location of the file on containers i.e., '/var/log/custom.log'
    ![AddLocationofFile](pictures/AddLocationofFile.png?raw=true)
  - Add Custom_Log_CL tag
  ![AddingCustomlogTag](pictures/AddingCustomlogTag.png?raw=true)

### Run test scripts

- Available modes: 
  - default: No options needed. Runs the install & reinstall tests on the latest agent with a 10 min wait time before verification.
  - `long`: Runs the tests just like the default mode but add a very longer wait time
  - `autoupgrade`: Runs the tests just like the default mode but waits till the agent is updated to a new version and terminates if running for more than 26 hours.
  - `instantupgrade`: Install the older version first and runs the default tests after force upgrade to newer version
  - `debug`: AZ CLI commands run with '--verbose' by default. Add 'debug' after short/long to see complete debug logs of az cli

#### All images in default mode

```bash
$ python -u oms_extension_tests.py
```

#### All images in default mode with debug in long run

```bash
$ python -u oms_extension_tests.py long debug
```

#### Subset of images

```bash
$ python -u oms_extension_tests.py image1 image2 ...
```

#### Autoupgrade of images (This option will wait until the extension is upgraded to the new version and continue to next steps after verifying data)

```bash
$ python -u oms_extension_tests.py autoupgrade image1 image2 ...
```

#### Instantupgrade of images (This option will install the desired older version of extension first and then force upgrade to the latest version)

Note: Must define a proper value for the `old_version` in parameters.json file else the program will encounter an undefined typeHandler error.

```bash
$ python -u oms_extension_tests.py instantupgrade image1 image2 ...
```
