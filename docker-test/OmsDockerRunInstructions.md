OMS Bundle test automation using Docker.

Command to build the Image:
```
$> docker build -rm -f <dockerfile> -t <image-name> .
```
Example:
For Ubuntu 16: docker build -rm -f ubuntu16/Dockerfile -t ubuntu16 .

Note:
1. Add your workspace-id, workspace-key, omsbundle settings
2. Make sure the $images set matches the docker images on your machine

To start the tests, Run the Powershell Script:
    docker-run.ps1

This space will be updated with more info.