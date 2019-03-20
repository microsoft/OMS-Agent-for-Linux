"""Build all or a subset of Docker images."""

import os
import sys
import re

IMAGES = ['ubuntu14', 'ubuntu16', 'ubuntu18', 'debian8', 'debian9', 'centos6', 'centos7', 'oracle6', 'oracle7']

def main():
    """Build images."""
    option = sys.argv[1]
    images = IMAGES
    if len(sys.argv) > 2:
        images = sys.argv[2:]
    if re.match('^([-/])*(build)', option):
        for i in images:
            print('\nBuilding image for {0}\n'.format(i))
            os.system('docker build --rm {0} -t {0}'.format(i))
    elif re.match('^([-/])*(pull)', option):
        for i in images:
            print('\nPulling {0} Image\n'.format(i))
            os.system('docker pull omslinuxagent.azurecr.io/{0}'.format(i))
            os.system('docker tag omslinuxagent.azurecr.io/{0} {0}'.format(i))

if __name__ == '__main__':
    main()
