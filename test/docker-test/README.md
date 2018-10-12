
# OMS Bundle Automated Testing with Docker

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

1. In oms_docker_tests.py, fill in the following:
  - `<bundle-file-name>` – path to OMS bundle to be tested
  - `<workspace-id>`, `<workspace-key>` – Log Analytics workspace ID, key
2. In parameters.json, fill in the following:
  - `<app-id>`, `<app-key>` – oms_verify service principal ID, key
  - `<subscription-id>` – subscription that hosts specified workspace
  - `<resource-group-name>` – resource group that hosts specified workspace
  - `<workspace-name>` – name of Log Analytics workspace
3. Ensure the images list in oms_docker_tests.py matches the docker images on your machine
4. Copy the bundle to test into the omsfiles directory
5. Install rstr and xeger to generate guid:
  - `pip install rstr xeger`

#### Execute tests
```
$ python oms_docker_tests.py
```
TODO: this space will be updated with more info
