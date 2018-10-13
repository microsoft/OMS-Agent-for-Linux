
# OMS Bundle Automated Testing with Docker

### Requirements

* Docker
* Python 2.7+
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
  - `<app-id>`, `<app-secret>` – verify_e2e service principal ID, secret
  - `<bundle-file-name>` – file name OMS bundle to be tested
  - `<resource-group-name>` – resource group that hosts specified workspace
  - `<subscription-id>` – ID of subscription that hosts specified workspace
  - `<workspace-name>`, `<workspace-id>`, `<workspace-key>` – Log Analytics workspace name, ID, key
2. Ensure the images list in oms_docker_tests.py matches the docker images on your machine
3. Copy the bundle to test into the omsfiles directory

#### Test all images
```
$ python oms_docker_tests.py
```

#### Test a subset of images
```
$ python oms_docker_tests.py image1 image2 ...
```
TODO: this space will be updated with more info
