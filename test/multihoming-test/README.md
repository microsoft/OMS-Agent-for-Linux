
# OMS Bundle Automated Testing with Docker

## Requirements

* Docker - Install for [Windows](https://docs.docker.com/docker-for-windows/install/) or [Linux](https://docs.docker.com/install/)
* Python 2.7+ & [pip](https://pip.pypa.io/en/stable/installing/)
* [Requests](http://docs.python-requests.org/en/master/), [ADAL](https://github.com/AzureAD/azure-activedirectory-library-for-python), [json2html](https://github.com/softvar/json2html)

```bash
$ pip install requests adal json2html
```

## Images currently supported for testing:
* CentOS 6 and 7
* Oracle Linux 6 and 7
* Debian 8 and 9
* Ubuntu 14.04, 16.04 and 18.04

## Getting the Docker Images

### From Azure Container Registry

Note: You must be a user of 'Geneva Monitoring Agent - LinuxMdsd' Subscription to pull images from Registry.
Log in to Azure Container Registry:
- Container Registry - Portal
Use the omslinuxagent Registry's Login server, Username and password to login
![RegistryAccessKeys](pictures/RegistryAccessKeys.png?raw=true)

  ```bash
  $ docker login --username omslinuxagent --password <password> omslinuxagent.azurecr.io
  ```

- [Container Registry - CLI](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-azure-cli#log-in-to-acr)
- [Container Registry - PowerShell](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-powershell#log-in-to-registry)

#### Pull all images

```bash
$ python -u build_images.py -pull
```

#### Pull a subset of images

```bash
$ python -u build_images.py -pull distro1 distro2 ...
```

### Using docker build

#### Build all images using Dockerfiles

```bash
$ python -u build_images.py -build
```

#### Build a subset of images using Dockerfiles

```bash
$ python -u build_images.py -build distro1 distro2 ...
```

## Running Tests

### Prepare

1. In parameters.json, fill in the following:
  - `<tenant>` – your AAD tenant, visible in Azure Portal > Azure Active Directory > Properties > Directory ID
  - `<app-id>`, `<app-secret>` – verify_e2e service principal ID, secret (available in OneNote document, or optionally register your own Azure Active Directory app in step 2)
  - `<bundle-file-name>` – file name OMS bundle to be tested
  - `<old-bundle-file-name>` - file name of old OMS bundle. Only if you are testing upgrade from older version. remove if not using (optional)
  - `<resource-group-name>` – resource group that hosts specified workspace
  - `<subscription-id>` – ID of subscription that hosts specified workspace
  - `<workspace-name>`, `<workspace-id>`, `<workspace-key>` – Log Analytics workspace name, ID, key
2. [Optional] Register your own AAD app to allow end-to-end verification script to access Microsoft REST APIs
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
3. Give the end-to-end verification script permission to read your workspace
  - Open workspace in Azure Portal
  - Access control (IAM) > Add
    - `Role` – Reader
    - `Assign access to` – Azure AD user, group, or application
    - `Select` – verify_e2e
  - Save
4. Ensure the images list in oms_docker_tests.py matches the docker images on your machine
5. Copy the bundle or bundles to test into the omsfiles directory
6. Custom Log Setup:
  - [Custom logs Docs](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-sources-custom-logs)
  - Add custom.log file to setup Custom_Log_CL
    ![AddingCustomlogFile](pictures/AddingCustomlogFile.png?raw=true)
  - Add location of the file on containers i.e., '/var/log/custom.log'
    ![AddLocationofFile](pictures/AddLocationofFile.png?raw=true)
  - Add Custom_Log_CL tag
    ![AddingCustomlogTag](pictures/AddingCustomlogTag.png?raw=true)


### Run test scripts

- Available modes (approximate runtime for all distros). Long and instantupgrade can be enabled together:
  - default (30m): No options needed. Runs the install & reinstall tests on the latest agent with a single verification.
  - `long` (+`LONG_DELAY`): Adds a long wait time (`LONG_DELAY` in oms_docker_tests.py) followed by a second verification.
  - `instantupgrade` (+15m): Install the older version first, verify status, upgrade to newer version and continue tests.
- With all modes, a subset of images can be tested by providing the corresponding image names

#### All images

```bash
$ python -u oms_docker_tests.py
```

#### Subset of images

```bash
$ python -u oms_docker_tests.py image1 image2 ...
```

#### All images, long-term

```bash
$ python -u oms_docker_tests.py long
```

#### Subset of images, Test upgrade from old bundle to new bundle

Note: Define a proper value for the `old oms bundle` in parameters.json file and bundle must be present in omsfiles folder

```bash
$ python -u oms_docker_tests.py instantupgrade image1 image2 ...
```
