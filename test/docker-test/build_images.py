"""Build all or a subset of Docker images."""

import os
import sys

IMAGES = ['ubuntu14', 'ubuntu16', 'ubuntu18', 'debian8', 'debian9', 'centos6', 'centos7', 'oracle6', 'oracle7']

def main():
    """Build images."""
    images = IMAGES
    if len(sys.argv) > 1:
        images = sys.argv[1:]
    for i in images:
        print('\nBuilding image for {}\n'.format(i))
        os.system('docker build --rm {} -t {}'.format(i, i))

if __name__ == '__main__':
    main()
