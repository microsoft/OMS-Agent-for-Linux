"""
Test the OMS Agent on all or a subset of images.

1. Create container and install agent
2. Wait for data to propagate to backend and check for data
3. Remove agent
4. Reinstall agent
5. Purge agent and delete container
"""

import json
import os
import subprocess
import re
import sys
import time
from collections import OrderedDict

from json2html import *
from verify_e2e import check_e2e

E2E_DELAY = 10 # Delay (minutes) before checking for data
images = ["ubuntu14", "ubuntu16", "ubuntu18", "debian8", "debian9", "centos6", "centos7", "oracle6", "oracle7"]
hostnames = []

if len(sys.argv) > 1:
    images = sys.argv[1:]

with open('{0}/parameters.json'.format(os.getcwd()), 'r') as f:
    parameters = f.read()
    if re.search(r'"<.*>"', parameters):
        print('Please replace placeholders in parameters.json')
        exit()
parameters = json.loads(parameters)

oms_bundle = parameters['oms bundle']
workspace_id = parameters['workspace id']
workspace_key = parameters['workspace key']

def append_file(src, dest):
    """Append contents of src to dest."""
    f = open(src, 'r')
    dest.write(f.read())
    f.close()

def write_log_command(cmd):
    """Print cmd to stdout and append it to logOpen file."""
    print(cmd)
    logOpen.write(cmd + '\n')
    logOpen.write('-' * 40)
    logOpen.write('\n')

# Remove intermediate log and html files
os.system('rm ./*.log ./*.html ./omsfiles/omsresults* 2> /dev/null')

resultlog = "finalresult.log"
resulthtml = "finalresult.html"
resultlogOpen = open(resultlog, 'a+')
resulthtmlOpen = open(resulthtml, 'a+')

htmlstart = """<!DOCTYPE html>
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

all_images_install_message = ""

# Run container and install omsagent
for image in images:
    container = image + "-container"
    imageLog = image + "result.log"
    htmlFile = image + "result.html"
    logOpen = open(imageLog, 'a+')
    htmlOpen = open(htmlFile, 'a+')
    write_log_command("Container: {0}".format(container))
    write_log_command("Install Logs: {0}".format(image))
    htmlOpen.write("<h1 id='{0}'> Container: {0} <h1>".format(image))
    os.system("docker container stop {0}".format(container))
    os.system("docker container rm {0}".format(container))
    uid = os.popen("docker run --name {0} -it --privileged=true -d {1}".format(container, image)).read()[:12]
    hostname = image + '-' + uid # uid is the truncated container uid
    hostnames.append(hostname)
    os.system("docker cp omsfiles/ {0}:/home/temp/".format(container))
    os.system("docker exec {0} hostname {1}".format(container, hostname))
    os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -preinstall".format(container))
    os.system("docker exec {0} sh /home/temp/omsfiles/{1} --purge | tee -a {2}".format(container, oms_bundle, imageLog))
    os.system("docker exec {0} sh /home/temp/omsfiles/{1} --upgrade -w {2} -s {3} | tee -a {4}".format(container, oms_bundle, workspace_id, workspace_key, imageLog))
    os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))
    os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
    os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
    write_log_command("Create Container and Install OMS Agent")
    append_file('omsfiles/omsresults.out', logOpen)
    os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
    htmlOpen.write("<h2> Install OMS Agent </h2>")
    append_file('omsfiles/omsresults.html', htmlOpen)
    logOpen.close()
    htmlOpen.close()
    if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
        x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
        if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
            all_images_install_message += """
                        <td><span style='background-color: #66ff99'>Install Success</span></td>"""
        elif x_out.rstrip() == "No Workspace":
            all_images_install_message += """
                        <td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
    else:
        all_images_install_message += """
                        <td><span style='background-color: red; color: white'>Install Failed</span></td>"""

# Inject logs
time.sleep(30)
for image in images:
    container = image + "-container"
    os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -injectlogs".format(container))

# Delay to allow data to propagate
for i in reversed(range(1, E2E_DELAY + 1)):
    print('E2E propagation delay: T-{} Minutes'.format(i))
    time.sleep(60)

all_images_verify_message = ""

# Verify data e2e
for hostname in hostnames:
    image = hostname.split('-')[0]
    imageLog = image + "result.log"
    htmlFile = image + "result.html"
    logOpen = open(imageLog, 'a+')
    htmlOpen = open(htmlFile, 'a+')
    os.system('rm e2eresults.json')
    check_e2e(hostname)

    # write detailed table for image
    htmlOpen.write("<h2> Verify Data from OMS workspace </h2>")
    write_log_command('Status After Verifying Data')
    with open('e2eresults.json', 'r') as infile:
        data = json.load(infile)
    results = data[image][0]
    logOpen.write(image + ':\n' + json.dumps(results, indent=4, separators=(',', ': ')) + '\n')
    # prepend distro column to results row before generating the table
    data = [OrderedDict([('Distro', image)] + results.items())]
    out = json2html.convert(data)
    htmlOpen.write(out)

    # write to summary table
    from verify_e2e import success_count
    if success_count == 6:
        all_images_verify_message += """
                        <td><span style='background-color: #66ff99'>Verify Success</td>"""
    elif 0 < success_count < 6:
        from verify_e2e import success_sources, failed_sources
        all_images_verify_message += """
                        <td><span style='background-color: #66ff99'>{0} Success</span> <br><br><span style='background-color: red; color: white'>{1} Failed</span></td>""".format(', '.join(success_sources), ', '.join(failed_sources))
    elif success_count == 0:
        all_images_verify_message += """
                        td><span style='background-color: red; color: white'>Verify Failed</span></td>"""


all_images_remove_message = ""

# Remove omsagent
for image in images:
    container = image + "-container"
    imageLog = image + "result.log"
    htmlFile = image + "result.html"
    logOpen = open(imageLog, 'a+')
    htmlOpen = open(htmlFile, 'a+')
    write_log_command("Remove Logs: {0}".format(image))
    os.system("docker exec {0} sh /home/temp/omsfiles/{1} --remove | tee -a {2}".format(container, oms_bundle, imageLog))
    os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
    os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
    write_log_command("Remove OMS Agent")
    append_file('omsfiles/omsresults.out', logOpen)
    os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
    htmlOpen.write("<h2> Remove OMS Agent </h2>")
    append_file('omsfiles/omsresults.html', htmlOpen)
    logOpen.close()
    htmlOpen.close()
    if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
        x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
        if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
            all_images_remove_message += """
                        <td><span style='background-color: red; color: white'>Remove Failed</span></td>"""
        elif x_out.rstrip() == "No Workspace":
            all_images_remove_message += """
                        <td><span style='background-color: red; color: white'>Onboarding Failed<span></td>"""
    else:
        all_images_remove_message += """
                        <td><span style='background-color: #66ff99'>Remove Success</span></td>"""


all_images_reinstall_message = ""

# Reinstall omsagent
for image in images:
    container = image + "-container"
    imageLog = image + "result.log"
    htmlFile = image + "result.html"
    logOpen = open(imageLog, 'a+')
    htmlOpen = open(htmlFile, 'a+')
    write_log_command("Reinstall Logs: {0}".format(image))
    os.system("docker exec {0} sh /home/temp/omsfiles/{1} --upgrade -w {2} -s {3} | tee -a {4}".format(container, oms_bundle, workspace_id, workspace_key, imageLog))
    os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))
    os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
    os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
    write_log_command("Reinstall OMS Agent")
    append_file('omsfiles/omsresults.out', logOpen)
    os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
    htmlOpen.write("<h2> Reinstall OMS Agent </h2>")
    append_file('omsfiles/omsresults.html', htmlOpen)
    logOpen.close()
    htmlOpen.close()
    if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
        x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
        if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
            all_images_reinstall_message += """
                        <td><span style='background-color: #66ff99'>Reinstall Success</span></td>"""
        elif x_out.rstrip() == "No Workspace":
            all_images_reinstall_message += """
                        <td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
    else:
        all_images_reinstall_message += """
                        <td><span style='background-color: red; color: white'>Reinstall Failed</span></td>"""


# Purge agent and delete container
for image in images:
    container = image + "-container"
    imageLog = image + "result.log"
    logOpen = open(imageLog, 'a+')
    write_log_command("Purge Logs: {0}".format(image))
    os.system("docker exec {0} sh /home/temp/omsfiles/{1} --purge | tee -a {2}".format(container, oms_bundle, imageLog))
    os.system("docker container stop {0}".format(container))
    os.system("docker container rm {0}".format(container))


imagesth = ""
resultsth = ""
for image in images:
    imagesth += """
            <th>{0}</th>""".format(image)
    resultsth += """
            <th><a href='#{0}'>{0} results</a></th>""".format(image)

statustable = """
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

# Create final html & log file
for image in images:
    imageLog = image + "result.log"
    htmlFile = image + "result.html"
    append_file(imageLog, resultlogOpen)
    append_file(htmlFile, resulthtmlOpen)

htmlend = """
</body>
</html>
"""
resulthtmlOpen.write(htmlend)
