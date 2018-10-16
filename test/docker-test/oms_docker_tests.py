import json
import os
import random
import rstr
import sys
import time
import xeger

from verify_e2e import check_e2e

E2E_DELAY = 10
images = ["ubuntu14", "ubuntu16", "ubuntu18", "debian8", "debian9","centos6", "centos7", "oracle6", "oracle7"]
hostnames = []

if len(sys.argv) > 1:
    images = sys.argv[1:]

with open('{}/_parameters.json'.format(os.getcwd()), 'r') as f:
    parameters = f.read()
parameters = json.loads(parameters)

oms_bundle = parameters['oms bundle']
workspace_id = parameters['workspace id']
workspace_key = parameters['workspace key']

def replace_items(infile, old_word, new_word):
    if not os.path.isfile(infile):
        print "Error on replace_word, not a regular file: "+infile
        sys.exit(1)

    f1=open(infile, 'r').read()
    f2=open(infile, 'w')
    m=f1.replace(old_word, new_word)
    f2.write(m)

# replace_items("omsfiles/perf.conf", "<workspace-id>", workspace_id)

for image in images:
    print image
    container = image + "-container"
    uid = rstr.xeger(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    hostname = image + '-' + uid
    hostnames.append(hostname)
    os.system("docker container stop {}".format(container))
    os.system("docker container rm {}".format(container))
    os.system("docker run --name {} --hostname {} -it --privileged=true -d {}".format(container, hostname, image))
    os.system("docker cp omsfiles/ {}:/home/temp/".format(container))
    os.system("docker exec {} python /home/temp/omsfiles/oms_run_script.py -preinstall".format(container))
    os.system("docker exec {} sh /home/temp/omsfiles/{} --purge".format(container, oms_bundle))
    os.system("docker exec {} sh /home/temp/omsfiles/{} --upgrade -w {} -s {}".format(container, oms_bundle, workspace_id, workspace_key))
    os.system("docker exec {} python /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))

time.sleep(E2E_DELAY * 60)

for hostname in hostnames:
    check_e2e(hostname)
