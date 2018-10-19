import json
import os
import subprocess
import re
import rstr
import sys
import time
import xeger

from verify_e2e import check_e2e

E2E_DELAY = 15
images = ["ubuntu14", "ubuntu16", "ubuntu18", "debian8", "debian9","centos6", "centos7", "oracle6", "oracle7"]
hostnames = []

if len(sys.argv) > 1:
    images = sys.argv[1:]

with open('{0}/parameters.json'.format(os.getcwd()), 'r') as f:
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
    logOpen.write(cmd + '\n')
    logOpen.write('-' * 40)
    logOpen.write('\n')
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

all_images_install_message=""

# Loop to run container and install omsagent
for image in images:
    imageLog = image+"result.log"
    htmlFile = image+"result.html"
    logOpen = open(imageLog, 'a+')
    htmlOpen = open(htmlFile, 'a+')
    container = image+"-container"
    uid = rstr.xeger(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    hostname = image + '-' + uid
    hostnames.append(hostname)
    writeLogCommand("Container: {0}".format(container))
    writeLogCommand("Install Logs: {0}".format(image))
    htmlOpen.write("<h1 id='{0}'> Container: {0} <h1>".format(image))
    os.system("docker container stop {0}".format(container))
    os.system("docker container rm {0}".format(container))
    os.system("docker run --name {0} --hostname {1} -it --privileged=true -d {2}".format(container, hostname, image))
    os.system("docker cp omsfiles/ {0}:/home/temp/".format(container))
    os.system("docker exec {0} python /home/temp/omsfiles/oms_run_script.py -preinstall".format(container))
    os.system("docker exec {0} sh /home/temp/omsfiles/{1} --purge | tee -a {2}".format(container, oms_bundle, imageLog))
    os.system("docker exec {0} sh /home/temp/omsfiles/{1} --upgrade -w {2} -s {3} | tee -a {4}".format(container, oms_bundle, workspace_id, workspace_key, imageLog))
    os.system("docker exec {0} python /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))
    os.system("docker exec {0} python /home/temp/omsfiles/oms_run_script.py -status".format(container))
    os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
    writeLogCommand("Create Container and Install OmsAgent")
    appendFile('omsfiles/omsresults.out', logOpen)
    os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
    htmlOpen.write("<h2> Install OmsAgent </h2>")
    appendFile('omsfiles/omsresults.html', htmlOpen)
    logOpen.close()
    htmlOpen.close()
    if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
        x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
        if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
            all_images_install_message+="""
                        <td style='background-color: green'>Install Success</td>"""
        elif x_out.rstrip() == "No Workspace":
            all_images_install_message+="""
                        <td style='background-color: yellow'>Onboarding Failed</td>"""
    else:
        all_images_install_message+="""
                        <td style='background-color: red'>Install Failed</td>"""

# Delay for 10 minutes
time.sleep(E2E_DELAY * 60)

all_images_verify_message=""

# Loop to verify data e2e
for hostname in hostnames:
    check_e2e(hostname)
    from verify_e2e import success_count
    if success_count == 6:
        all_images_verify_message+="""
                        <td style='background-color: green'>Verify Success</td>"""
    elif success_count < 6 and success_count > 0:
        from verify_e2e import success_sources, failed_sources
        all_images_verify_message+="""
                        <td style='background-color: yellow'>{0} Success <br><br>{1} Failed</td>""".format(', '.join(success_sources), ', '.join(failed_sources))
    elif success_count == 0:
        all_images_verify_message+="""
                        <td style='background-color: red'>Verify Failed</td>"""


all_images_remove_message=""

# Loop to remove omsagent
for image in images:
    container=image+"-container"
    imageLog = image+"result.log"
    htmlFile = image+"result.html"
    logOpen = open(imageLog, 'a+')
    htmlOpen = open(htmlFile, 'a+')
    writeLogCommand("Remove Logs: {0}".format(image))
    os.system("docker exec {0} sh /home/temp/omsfiles/{1} --remove | tee -a {2}".format(container, oms_bundle, imageLog))
    os.system("docker exec {0} python /home/temp/omsfiles/oms_run_script.py -status".format(container))
    os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
    writeLogCommand("Remove OmsAgent")
    appendFile('omsfiles/omsresults.out', logOpen)
    os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
    htmlOpen.write("<h2> Remove OmsAgent </h2>")
    appendFile('omsfiles/omsresults.html', htmlOpen)
    logOpen.close()
    htmlOpen.close()
    if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
        x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
        if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
            all_images_remove_message+="""
                        <td style='background-color: red'>Remove Failed</td>"""
        elif x_out.rstrip() == "No Workspace":
            all_images_remove_message+="""
                        <td style='background-color: yellow'>Onboarding Failed</td>"""
    else:
        all_images_remove_message+="""
                        <td style='background-color: green'>Remove Success</td>"""


all_images_reinstall_message=""

# Loop to reinstall omsagent
for image in images:
    container=image+"-container"
    imageLog = image+"result.log"
    htmlFile = image+"result.html"
    logOpen = open(imageLog, 'a+')
    htmlOpen = open(htmlFile, 'a+')
    writeLogCommand("Reinstall Logs: {0}".format(image))
    os.system("docker exec {0} sh /home/temp/omsfiles/{1} --upgrade -w {2} -s {3} | tee -a {4}".format(container, oms_bundle, workspace_id, workspace_key, imageLog))
    os.system("docker exec {0} python /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))
    os.system("docker exec {0} python /home/temp/omsfiles/oms_run_script.py -status".format(container))
    os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
    writeLogCommand("Reinstall OmsAgent")
    appendFile('omsfiles/omsresults.out', logOpen)
    os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
    htmlOpen.write("<h2> Reinstall OmsAgent </h2>")
    appendFile('omsfiles/omsresults.html', htmlOpen)
    logOpen.close()
    htmlOpen.close()
    if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
        x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
        if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
            all_images_reinstall_message+="""
                        <td style='background-color: green'>Reinstall Success</td>"""
        elif x_out.rstrip() == "No Workspace":
            all_images_reinstall_message+="""
                        <td style='background-color: yellow'>Onboarding Failed</td>"""
    else:
        all_images_reinstall_message+="""
                        <td style='background-color: red'>Reinstall Failed</td>"""
    

# Loop to purge and delete container
for image in images:
    container=image+"-container"
    imageLog = image+"result.log"
    logOpen = open(imageLog, 'a+')
    writeLogCommand("Purge Logs: {0}".format(image))
    os.system("docker exec {0} sh /home/temp/omsfiles/{1} --purge | tee -a {2}".format(container, oms_bundle, imageLog))
    os.system("docker container stop {0}".format(container))
    os.system("docker container rm {0}".format(container))


imagesth = ""
resultsth = ""
for image in images:
    imagesth+="""
            <th>{0}</th>""".format(image)
    resultsth+="""
            <th><a href='#{0}'>{0} results</a></th>""".format(image)

statustable="""
<table>
  <caption><h2>Test Result Table</h2><caption>
  <tr>
    <th>Distro</th>
    {0}
  </tr>
  <tr>
    <td>Install OMSAgent</td>
    {1}
  </tr>
  <tr>
    <td>Verify Data</td>
    {2}
  </tr>
  <tr>
    <td>Remove OMSAgent</td>
    {3}
  </tr>
  <tr>
    <td>Reinstall OMSAgent</td>
    {4}
  </tr>
  <tr>
    <td>Result Link</td>
    {5}
  <tr>
</table>
""".format(imagesth, all_images_install_message, all_images_verify_message, all_images_remove_message, all_images_reinstall_message, resultsth)
resulthtmlOpen.write(statustable)

# Loop to create final html & log file
for image in images:
    imageLog = image+"result.log"
    htmlFile = image+"result.html"
    appendFile(imageLog, resultlogOpen)
    appendFile(htmlFile, resulthtmlOpen)

htmlend="""
</body>
</html>
"""
resulthtmlOpen.write(htmlend)