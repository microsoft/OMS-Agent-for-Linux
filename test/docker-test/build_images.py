import os
import sys

images = ['ubuntu14', 'ubuntu16', 'ubuntu18', 'debian8', 'debian9','centos6', 'centos7', 'oracle6', 'oracle7']

if len(sys.argv) > 1:
    images = sys.argv[1:]

for i in images:
    print('\nBuilding image for {}\n'.format(i))
    os.system('docker build {} -t {}'.format(i, i))
