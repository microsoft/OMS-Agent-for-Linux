# Trying the container solution pack for Operations Management Suite
## What can you do with the container solution pack
With this feature, you'll be able to:
* See information about all hosts in a single location 
* Know which containers are running, what image they’re running, and where they’re running 
* See an audit trail for actions on containers 
* Troubleshoot by viewing and searching centralized logs without remoting to the Docker hosts  
* Find containers that may be “noisy neighbors” and consuming excess resources on a host 
* View centralized CPU, memory, storage, and network usage and performance information for containers 

## Setting up
Your container hosts must be running:
* At least Docker 1.8
* Ubuntu 14.04, 15.04
* Amazon Linux 2015.09
* openSUSE 13.2
* CentOS 7
* SUSE Linux Enterprise Server 12

You'll need to add the OMS Agent for Linux to each host (instructions here)[INSERT LINK] and then do the following to configure your containers to use the FluentD logging driver:

* Edit `/etc/default/docker` and add this line:
```
DOCKER_OPTS="--log-driver=fluentd --log-opt fluentd-address=localhost:25225"
```
* Save the file and then restart the docker service:
```
service docker restart
```

## What now?
Once you’re set up, we’d like you to try the following scenarios and play around with the system. What works? What is missing? What else do you need for this to be useful for you? Let us know at OMSContainers@microsoft.com.

### Overview
Look at the Container top tile – it’s intended to show you a quick overview of the system. Does it contain the information you need to see first? If not, tell us what you expect to see instead.

![DockerTopView]()

The top tile shows hosts that are overwhelmed with CPU or Memory usage (>90%), as well as an overview of how many containers you have in the environment and whether they’re failed, running, or stopped. 
