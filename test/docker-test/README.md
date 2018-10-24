
# OMS Bundle Automated Testing with Docker

## Requirements

* Docker - Install for [Windows](https://docs.docker.com/docker-for-windows/install/) or [Linux](https://docs.docker.com/install/)
* Python 2.7+ & [pip](https://pip.pypa.io/en/stable/installing/)
* [Requests](http://docs.python-requests.org/en/master/), [ADAL](https://github.com/AzureAD/azure-activedirectory-library-for-python), [rstr](https://bitbucket.org/leapfrogdevelopment/rstr/overview), [xeger](https://github.com/crdoconnor/xeger)

```bash
$ pip install requests adal rstr xeger
```

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

### Pull all images

```bash
$ python -u build_images.py -pull
```

#### Pull a subset of images

```bash
$ python -u build_images.py -pull distro1 distro2 ...
```

### Using docker builder

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
  - `<app-id>`, `<app-secret>` – verify_e2e service principal ID, secret (available in OneNote document)
  - `<bundle-file-name>` – file name OMS bundle to be tested
  - `<resource-group-name>` – resource group that hosts specified workspace
  - `<subscription-id>` – ID of subscription that hosts specified workspace
  - `<workspace-name>`, `<workspace-id>`, `<workspace-key>` – Log Analytics workspace name, ID, key
2. Ensure the images list in oms_docker_tests.py matches the docker images on your machine
3. Copy the bundle to test into the omsfiles directory
4. Custom Log Setup:
  - [Custom logs Docs](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-sources-custom-logs)
  - Add custom.log file to setup Custom_Log_CL
    ![AddingCustomlogFile](pictures/AddingCustomlogFile.png?raw=true)
  - Add location of the file on containers i.e., '/var/log/custom.log'
    ![AddLocationofFile](pictures/AddLocationofFile.png?raw=true)
  - Add Custom_Log_CL tag
    ![AddingCustomlogTag](pictures/AddingCustomlogTag.png?raw=true)


### Run test scripts

#### All images

```bash
$ python -u oms_docker_tests.py
```

#### Subset of images

```bash
$ python -u oms_docker_tests.py image1 image2 ...
```
