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

with open('{}/parameters.json'.format(os.getcwd()), 'r') as f:
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

def appendFile(filename, destFile):
    f = open(filename, 'r')
    destFile.write(f.read())
    f.close()

def writeLogCommand(cmd):
    print(cmd)
    outOpen.write(cmd + '\n')
    outOpen.write('-' * 40)
    outOpen.write('\n')
    return

resultlog = "finalresult.log"
resulthtml = "finalresult.html"
resultlogOpen = open(resultlog, 'a+')
resulthtmlOpen = open(resulthtml, 'a+')

htmlstart="""<!DOCTYPE html>
<html>
<head>
<style>
table {
    font-family: arial, sans-serif;
    border-collapse: collapse;
    width: 100%;
}

td, th {
    border: 1px solid #dddddd;
    text-align: left;
    padding: 8px;
}

tr:nth-child(even) {
    background-color: #dddddd;
}
</style>
</head>
<body>
"""
resulthtmlOpen.write(htmlstart)

#Loop to run container and install omsagent
for image in images:
    resultFile = image+"result.log"
    htmlFile = image+"result.html"
    outOpen = open(resultFile, 'a+')
    htmlOpen = open(htmlFile, 'a+')
    container = image+"-container"
    uid = rstr.xeger(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    hostname = image + '-' + uid
    hostnames.append(hostname)
<<<<<<< HEAD
    writeLogCommand("Container: {}".format(image))
    htmlOpen.write("<h1> Container: {} <h1>".format(image))
=======
>>>>>>> 705e01bb1fb994444e2f2072a623dcd44983397a
    os.system("docker container stop {}".format(container))
    os.system("docker container rm {}".format(container))
    os.system("docker run --name {} --hostname {} -it --privileged=true -d {}".format(container, hostname, image))
    os.system("docker cp omsfiles/ {}:/home/temp/".format(container))
    os.system("docker exec {} python /home/temp/omsfiles/oms_run_script.py -preinstall".format(container))
    os.system("docker exec {} sh /home/temp/omsfiles/{} --purge".format(container, oms_bundle))
    os.system("docker exec {} sh /home/temp/omsfiles/{} --upgrade -w {} -s {}".format(container, oms_bundle, workspace_id, workspace_key))
    os.system("docker exec {} python /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))
    os.system("docker exec {} python /home/temp/omsfiles/oms_run_script.py -status".format(container))
    os.system("docker cp {}:/home/temp/omsresults.out omsfiles/".format(container))
    writeLogCommand("Create Container and Install OmsAgent")
    appendFile('omsfiles/omsresults.out', outOpen)
    os.system("docker cp {}:/home/temp/omsresults.html omsfiles/".format(container))
    htmlOpen.write("<h2> Install OmsAgent </h2>")
    appendFile('omsfiles/omsresults.html', htmlOpen)
    outOpen.close()
    htmlOpen.close()

#Delay for 10 minutes
time.sleep(E2E_DELAY * 60)

<<<<<<< HEAD
#Loop to verify data e2e
=======
>>>>>>> 705e01bb1fb994444e2f2072a623dcd44983397a
for hostname in hostnames:
    check_e2e(hostname)

#Loop to purge omsagent
for image in images:
    container=image+"-container"
    resultFile = image+"result.log"
    htmlFile = image+"result.html"
    outOpen = open(resultFile, 'a+')
    htmlOpen = open(htmlFile, 'a+')
    os.system("docker exec {} sh /home/temp/omsfiles/{} --purge".format(container, oms_bundle))
    os.system("docker exec {} python /home/temp/omsfiles/oms_run_script.py -status".format(container))
    os.system("docker cp {}:/home/temp/omsresults.out omsfiles/".format(container))
    writeLogCommand("Remove OmsAgent")
    appendFile('omsfiles/omsresults.out', outOpen)
    os.system("docker cp {}:/home/temp/omsresults.html omsfiles/".format(container))
    htmlOpen.write("<h2> Remove OmsAgent </h2>")
    appendFile('omsfiles/omsresults.html', htmlOpen)
    outOpen.close()
    htmlOpen.close()

#Loop to reinstall omsagent
for image in images:
    container=image+"-container"
    resultFile = image+"result.log"
    htmlFile = image+"result.html"
    outOpen = open(resultFile, 'a+')
    htmlOpen = open(htmlFile, 'a+')
    os.system("docker exec {} sh /home/temp/omsfiles/{} --upgrade -w {} -s {}".format(container, oms_bundle, workspace_id, workspace_key))
    os.system("docker exec {} python /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))
    os.system("docker exec {} python /home/temp/omsfiles/oms_run_script.py -status".format(container))
    os.system("docker cp {}:/home/temp/omsresults.out omsfiles/".format(container))
    writeLogCommand("Reinstall OmsAgent")
    appendFile('omsfiles/omsresults.out', outOpen)
    os.system("docker cp {}:/home/temp/omsresults.html omsfiles/".format(container))
    htmlOpen.write("<h2> Reinstall OmsAgent </h2>")
    appendFile('omsfiles/omsresults.html', htmlOpen)
    outOpen.close()
    htmlOpen.close()

#Loop to purge and delete container
for image in images:
    container=image+"-container"
    os.system("docker exec {} sh /home/temp/omsfiles/{} --purge".format(container, oms_bundle))
    os.system("docker container stop {}".format(container))
    os.system("docker container rm {}".format(container))

#Loop to create final html & log file
for image in images:
    resultFile = image+"result.log"
    htmlFile = image+"result.html"
    appendFile(resultFile, resultlogOpen)
    appendFile(htmlFile, resulthtmlOpen)

htmlend="""
</body>
</html>
"""
resulthtmlOpen.write(htmlend)