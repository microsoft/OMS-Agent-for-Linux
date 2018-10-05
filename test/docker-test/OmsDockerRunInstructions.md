
OMS Bundle test automation using Docker.

Command to build the Image:
```
$> docker build -rm -f <dockerfile> -t <image-name> .
```
Example:
For Ubuntu 16: docker build -rm -f ubuntu16/Dockerfile -t ubuntu16 .

Note:
1. Update workspace-id, workspace-key, omsbundle settings in OMS_TestsWithDocker file
2. Make sure the Images set matches the docker images on your machine

To start the tests, Run the Python Script:
    python OMS_TestsWithDocker.py

This space will be updated with more info.