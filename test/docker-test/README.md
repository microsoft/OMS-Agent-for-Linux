
# OMS Bundle Automated Testing with Docker

### Requirements

* Docker - Install for [Windows](https://docs.docker.com/docker-for-windows/install/) or [Linux](https://docs.docker.com/install/)
* Python 2.7+ & [pip](https://pip.pypa.io/en/stable/installing/)
* [Requests](http://docs.python-requests.org/en/master/), [ADAL](https://github.com/AzureAD/azure-activedirectory-library-for-python), [rstr](https://bitbucket.org/leapfrogdevelopment/rstr/overview), [xeger](https://github.com/crdoconnor/xeger)

```
$ pip install requests adal rstr xeger
```


## Building the Docker Images

#### Build all images
```
$ python build_images.py
```
#### Build a subset of images
```
$ python build_images.py distro1 distro2 ...
```


## Running Tests

#### Prepare

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
    ![AddingCustomlogFile](pictures/AddingCustomlogFile.PNG?raw=true)
  - Add location of the file on containers i.e., '/var/log/custom.log'
    ![AddLocationofFile](pictures/AddLocationofFile.PNG?raw=true)
  - Add Custom_Log_CL tag
    ![AddingCustomlogTag](pictures/AddingCustomlogTag.PNG?raw=true)

#### Test all images
```
$ python oms_docker_tests.py
```

#### Test a subset of images
```
$ python oms_docker_tests.py image1 image2 ...
```
