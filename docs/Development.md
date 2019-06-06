

### Get the source code
Besides the omsagent core itself, OMS Agent consists of an number of other components and their kits (shell bundles).
We have a root project called Build-OMS-Agent-for-Linux in the GitHub to build them all, which references the 10 components as submodules.

- auoms/auoms-kits (Auditd plugin for OMS agent) 
- dsc/dsc-kits (Desired State Configuration) 
- omi/omi-kits (Open Management Infrastructure) 
- opsmgr-kits (Operations Manager) 
- pal (Platform Abstraction Layer) 
- scxcore-kits (System Center Cross Platform Provider for Operations Manager) 



To build the bundle, you need to clone the Build-OMS-Agent-for-Linux repository.  
```
git clone --recursive git@github.com:Microsoft/Build-OMS-Agent-for-Linux.git /home/$(whoami)

cd /home/$(whoami)/Build-OMS-Agent-for-Linux/omsagent
git checkout master
git branch my-feature-1
```

### Setup environment with a build container (Docker)
Our build environment is based on Centos, you can setup your own dev container
by choosing the right docker file under ./build/docker folder.

Example using Dockerfile.centos6:

```
docker build -t oms-centos6-x64 -f /home/$(whoami)/Build-OMS-Agent-for-Linux/omsagent/build/docker/Dockerfile.centos6 .
```

You can instead pull the existing container image from Docker HUB repository, you should often pull this image to keep your local build up-to-date:
```
docker pull abenbachir/oms-centos6-x64
```

Then you can start a build container instance:
```
docker run --rm -itv /home/$(whoami)/:/home/scratch/Build-OMS-Agent-for-Linux -w /home/scratch/OMS/Build-OMS-Agent-for-Linux/omsagent/build abenbachir/oms-centos6-x64:latest
```

### Building steps
Once inside the build container, do the following to build omsagent:
```
./configure --enable-ulinux
make
```
When the build is completed, the bundle will be built out in Build-OMS-Agent-for-Linux/omsagent/target/Linux_ULINUX_1.0_x64_64_Release 


You can run unit tests locally  with:
```
make unittest
```

You can clean-up and reset your workspace with:
```
make distclean
```