"""
Test the OMS Agent on all or a subset of images.

Setup: read parameters and setup HTML report
Test:
1. Create container and install agent
2. Wait for data to propagate to backend and check for data
3. Remove agent
4. Reinstall agent
?. Optionally, wait for hours and check data and agent status
5. Purge agent and delete container
Finish: compile HTML report and log file
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
LONG_DELAY = 250 # Delay (minutes) before rechecking agent
images = ["ubuntu14", "ubuntu16", "ubuntu18", "debian8", "debian9", "centos6", "centos7", "oracle6", "oracle7"]
hostnames = []

if len(sys.argv) == 1:
    print(('Please indicate run length (short or long) and optional image subset:\n'
           '$ python -u oms_docker_tests.py length [image...]'))
is_long = sys.argv[1] == 'long'

if len(sys.argv) > 2: # user has specified image subset
    images = sys.argv[2:]

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

def write_log_command(cmd, log):
    """Print cmd to stdout and append it to log file."""
    print(cmd)
    log.write(cmd + '\n')
    log.write('-' * 40)
    log.write('\n')

# Remove intermediate log and html files
os.system('rm ./*.log ./*.html ./omsfiles/omsresults* 2> /dev/null')

result_html_file = open("finalresult.html", 'a+')

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
result_html_file.write(htmlstart)

def main():
    """Orchestrate fundemental testing steps onlined in header docstring."""
    install_msg = install_agent()
    inject_logs()
    verify_msg = verify_data()
    remove_msg = remove_agent()
    reinstall_msg = reinstall_agent()
    if is_long:
        # TODO add visual counter, log
        time.sleep(LONG_DELAY)
        inject_logs()
        long_verify_msg = verify_data()
        long_status_msg = check_status()
    else:
        long_verify_msg, long_status_msg = None, None
    purge_delete_agent()
    messages = (install_msg, verify_msg, remove_msg,
                reinstall_msg, long_verify_msg, long_status_msg)
    create_report(messages)

def install_agent():
    """Run container and install the OMS agent, returning HTML results."""
    message = ""
    for image in images:
        container = image + "-container"
        log_path = image + "result.log"
        html_path = image + "result.html"
        log_file = open(log_path, 'a+')
        html_file = open(html_path, 'a+')
        write_log_command("Container: {0}".format(container), log_file)
        write_log_command("Install Logs: {0}".format(image), log_file)
        html_file.write("<h1 id='{0}'> Container: {0} <h1>".format(image))
        os.system("docker container stop {0} 2> /dev/null".format(container))
        os.system("docker container rm {0} 2> /dev/null".format(container))
        uid = os.popen("docker run --name {0} -it --privileged=true -d {1}".format(container, image)).read()[:12]
        hostname = image + '-' + uid # uid is the truncated container uid
        hostnames.append(hostname)
        os.system("docker cp omsfiles/ {0}:/home/temp/".format(container))
        os.system("docker exec {0} hostname {1}".format(container, hostname))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -preinstall".format(container))
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --purge | tee -a {2}".format(container, oms_bundle, log_path))
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --upgrade -w {2} -s {3} | tee -a {4}".format(container, oms_bundle, workspace_id, workspace_key, log_path))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
        os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
        write_log_command("Create Container and Install OMS Agent", log_file)
        append_file('omsfiles/omsresults.out', log_file)
        os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
        html_file.write("<h2> Install OMS Agent </h2>")
        append_file('omsfiles/omsresults.html', html_file)
        log_file.close()
        html_file.close()
        if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
            x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
            if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
                message += """<td><span style='background-color: #66ff99'>Install Success</span></td>"""
            elif x_out.rstrip() == "No Workspace":
                message += """<td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
        else:
            message += """<td><span style='background-color: red; color: white'>Install Failed</span></td>"""
    return message

def inject_logs():
    """Inject logs."""
    time.sleep(30)
    for image in images:
        container = image + "-container"
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -injectlogs".format(container))

def verify_data():
    """Verify data end-to-end, returning HTML results."""
    # Delay to allow data to propagate
    for i in reversed(range(1, E2E_DELAY + 1)):
        print('E2E propagation delay: T-{} Minutes'.format(i))
        time.sleep(60)

    message = ""
    for hostname in hostnames:
        image = hostname.split('-')[0]
        log_path = image + "result.log"
        html_path = image + "result.html"
        log_file = open(log_path, 'a+')
        html_file = open(html_path, 'a+')
        os.system('rm e2eresults.json')
        check_e2e(hostname)

        # write detailed table for image
        html_file.write("<h2> Verify Data from OMS workspace </h2>")
        write_log_command('Status After Verifying Data', log_file)
        with open('e2eresults.json', 'r') as infile:
            data = json.load(infile)
        results = data[image][0]
        log_file.write(image + ':\n' + json.dumps(results, indent=4, separators=(',', ': ')) + '\n')
        # prepend distro column to results row before generating the table
        data = [OrderedDict([('Distro', image)] + results.items())]
        out = json2html.convert(data)
        html_file.write(out)

        # write to summary table
        from verify_e2e import success_count
        if success_count == 6:
            message += """<td><span style='background-color: #66ff99'>Verify Success</td>"""
        elif 0 < success_count < 6:
            from verify_e2e import success_sources, failed_sources
            message += """<td><span style='background-color: #66ff99'>{0} Success</span> <br><br><span style='background-color: red; color: white'>{1} Failed</span></td>""".format(', '.join(success_sources), ', '.join(failed_sources))
        elif success_count == 0:
            message += """<td><span style='background-color: red; color: white'>Verify Failed</span></td>"""
    return message

def remove_agent():
    """Remove the OMS agent, returning HTML results."""
    message = ""
    for image in images:
        container = image + "-container"
        log_path = image + "result.log"
        html_path = image + "result.html"
        log_file = open(log_path, 'a+')
        html_file = open(html_path, 'a+')
        write_log_command("Remove Logs: {0}".format(image), log_file)
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --remove | tee -a {2}".format(container, oms_bundle, log_path))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
        os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
        write_log_command("Remove OMS Agent", log_file)
        append_file('omsfiles/omsresults.out', log_file)
        os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
        html_file.write("<h2> Remove OMS Agent </h2>")
        append_file('omsfiles/omsresults.html', html_file)
        log_file.close()
        html_file.close()
        if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
            x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
            if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
                message += """<td><span style='background-color: red; color: white'>Remove Failed</span></td>"""
            elif x_out.rstrip() == "No Workspace":
                message += """<td><span style='background-color: red; color: white'>Onboarding Failed<span></td>"""
        else:
            message += """<td><span style='background-color: #66ff99'>Remove Success</span></td>"""
    return message

def reinstall_agent():
    """Reinstall the OMS agent, returning HTML results."""
    message = ""
    for image in images:
        container = image + "-container"
        log_path = image + "result.log"
        html_path = image + "result.html"
        log_file = open(log_path, 'a+')
        html_file = open(html_path, 'a+')
        write_log_command("Reinstall Logs: {0}".format(image), log_file)
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --upgrade -w {2} -s {3} | tee -a {4}".format(container, oms_bundle, workspace_id, workspace_key, log_path))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
        os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
        write_log_command("Reinstall OMS Agent", log_file)
        append_file('omsfiles/omsresults.out', log_file)
        os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
        html_file.write("<h2> Reinstall OMS Agent </h2>")
        append_file('omsfiles/omsresults.html', html_file)
        log_file.close()
        html_file.close()
        if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
            x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
            if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
                message += """<td><span style='background-color: #66ff99'>Reinstall Success</span></td>"""
            elif x_out.rstrip() == "No Workspace":
                message += """<td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
        else:
            message += """<td><span style='background-color: red; color: white'>Reinstall Failed</span></td>"""
        return message

def check_status():
    """Check agent status."""
    message = ""
    for image in images:
        container = image + "-container"
        log_path = image + "result.log"
        html_path = image + "result.html"
        log_file = open(log_path, 'a+')
        html_file = open(html_path, 'a+')
        write_log_command("Check Status: {0}".format(image), log_file)
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
        os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
        append_file('omsfiles/omsresults.out', log_file)
        os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
        html_file.write("<h2> Check OMS Agent Status </h2>")
        append_file('omsfiles/omsresults.html', html_file)
        log_file.close()
        html_file.close()
        if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
            x_out = str(subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True))
            if 'Onboarded' in x_out:
                message += """<td><span style='background-color: #66ff99'>Agent Running</span></td>"""
            elif 'Warning' in x_out:
                message += """<td><span style='background-color: red; color: white'>Agent Registered, Not Running</span></td>"""
            elif 'Saved' in x_out:
                message += """<td><span style='background-color: red; color: white'>Agent Not Running, Not Registered</span></td>"""
            elif 'Failure' in x_out:
                message += """<td><span style='background-color: red; color: white'>Agent Not Running, Not Onboarded</span></td>"""
        else:
            message += """<td><span style='background-color: red; color: white'>Agent Not Installed</span></td>"""
    return message

def purge_delete_agent():
    """Purge the OMS agent and delete container."""
    for image in images:
        container = image + "-container"
        log_path = image + "result.log"
        log_file = open(log_path, 'a+')
        write_log_command("Purge Logs: {0}".format(image), log_file)
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --purge | tee -a {2}".format(container, oms_bundle, log_path))
        os.system("docker container stop {0}".format(container))
        os.system("docker container rm {0}".format(container))

def create_report(messages):
    """Compile the final HTML report."""
    install_msg, verify_msg, remove_msg, reinstall_msg, long_verify_msg, long_status_msg = messages
    result_log_file = open("finalresult.log", 'a+')

    # summary table
    imagesth = ""
    resultsth = ""
    for image in images:
        imagesth += """
                <th>{0}</th>""".format(image)
        resultsth += """
                <th><a href='#{0}'>{0} results</a></th>""".format(image)

    # pre-compile long-running summary
    if long_verify_msg and long_status_msg:
        long_running_summary = """
        <tr>
          <td>Long-term Verify Data</td>
          {0}
        </tr>
        <tr>
          <td>Long-term Status</td>
          {1}
        </tr>
        """.format(long_verify_msg, long_status_msg)
    else:
        long_running_summary = ""

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
      {5}
      <tr>
        <td>Result Link</td>
        {6}
      <tr>
    </table>
    """.format(imagesth, install_msg, verify_msg, remove_msg, reinstall_msg, long_running_summary, resultsth)
    result_html_file.write(statustable)

    # Create final html & log file
    for image in images:
        append_file(image + "result.log", result_log_file)
        append_file(image + "result.html", result_html_file)

    htmlend = """
    </body>
    </html>
    """
    result_html_file.write(htmlend)

if __name__ == '__main__':
    main()
