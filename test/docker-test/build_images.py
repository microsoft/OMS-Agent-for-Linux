"""Build all or a subset of Docker images."""

import os
import sys
import re

IMAGES = ['ubuntu14', 'ubuntu16', 'ubuntu18', 'ubuntu20py3', 'debian8', 'debian9', 'debian10', 'centos6', 'centos7', 'centos8py3', 'oracle6', 'oracle7', 'redhat6', 'redhat7', 'redhat8py3']
# IMAGES = ['ubuntu14', 'ubuntu16', 'ubuntu18', 'ubuntu20', 'ubuntu20py3', 'debian8', 'debian9', 'debian10', 'centos6', 'centos7', 'centos8', 'centos8py3', 'oracle6', 'oracle7', 'redhat6', 'redhat7', 'redhat8', 'redhat8py3']

def main():
    """Build images."""

    # needed to enable secure use of secrets in build process, see below for details
    # https://medium.com/@tonistiigi/build-secrets-and-ssh-forwarding-in-docker-18-09-ae8161d066
    os.environ["DOCKER_BUILDKIT"] = "1"

    option = sys.argv[1]
    images = IMAGES
    if len(sys.argv) > 2:
        images = sys.argv[2:]
    if re.match('^([-/])*(build)', option):
        for i in images:
            print('\nBuilding image for {0}\n'.format(i))
            creds_flag = '--secret id=creds,src=./redhat_creds' if i.startswith('redhat') else ''
            os.system('docker build --rm {1} dockerfiles/{0} -t {0}'.format(i, creds_flag))
    elif re.match('^([-/])*(pull)', option):
        for i in images:
            print('\nPulling {0} Image\n'.format(i))
            os.system('docker pull omslinuxagent.azurecr.io/{0}'.format(i))
            os.system('docker tag omslinuxagent.azurecr.io/{0} {0}'.format(i))

if __name__ == '__main__':
    main()
