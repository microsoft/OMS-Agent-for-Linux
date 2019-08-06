"""
Test the OMS Agent Multi Homing feature on all or a subset of images.

Setup: read parameters and setup HTML report
Test:
1. Create container, install agent and onboard to WS #1
2. Wait for data to propagate to backend and check for data
3. Onboard the agent to WS #2 and wait for data to propogate to the backend
4. Verify the data
5. Add new configs for WS #1 and WS #2 and verify new data being propogated
5. Purge agent and delete container
Finish: compile HTML report and log file
"""

import json
import os
import subprocess
import re
import sys
import shutil
from glob import glob
from time import sleep
from collections import OrderedDict
from datetime import datetime, timedelta

from json2html import *
from verify_e2e import check_e2e

DEFAULT_DELAY = 10 # Delay (minutes) before checking for data
LONG_DELAY = 250 # Delay (minutes) before rechecking agent
images = [
    "ubuntu14",
    "ubuntu16",
    "ubuntu18", 
    "debian8", 
    "debian9", 
    "centos6", 
    "centos7", 
    "oracle6", 
    "oracle7"
    ]
hostnames = []
install_times = {}

if len(sys.argv) > 0:
    options = sys.argv[1:]
    images = [i for i in options if i in images] or images # if parsed images are empty, revert to full list
    is_long = 'long' in options
else:
    is_long = False

with open('{0}/parameters.json'.format(os.getcwd()), 'r') as f:
    parameters = f.read()
    if re.search(r'"<.*>"', parameters):
        print('Please replace placeholders in parameters.json')
        exit()
    parameters = json.loads(parameters)

try:
    if parameters['oms bundle'] and os.path.isfile('omsfiles/'+parameters['oms bundle']):
        oms_bundle = parameters['oms bundle']

except KeyError:
    print('parameters not defined correctly or omsbundle file not found')

workspace_id_1 = parameters['workspace id 1']
workspace_key_1 = parameters['workspace key 1']
workspace_id_2 = parameters['workspace id 2']
workspace_key_2 = parameters['workspace key 2']

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

def get_time_diff(timevalue1, timevalue2):
    """Get time difference in minutes and seconds"""
    timediff = timevalue2 - timevalue1
    minutes, seconds = divmod(timediff.days * 86400 + timediff.seconds, 60)
    return minutes, seconds

# Remove intermediate log and html files
os.system('rm -rf ./*.log ./*.html ./omsfiles/omsresults* ./results 2> /dev/null')

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
    print("####"*15 + "Installing Agent for the first time" + "####"*15)
    install_msg = install_agent(oms_bundle, workspace_id_1, workspace_key_1, "workspace_1")
    print("####"*15 + "Verifying Agent for the first Workspace" + "####"*15)
    verify_msg_1 = verify_data(1, workspace_id_1)
    print("####"*15 + "Onboarding Agent for the Second Workspace" + "####"*15)
    onboard_2_msg = onboard_agent(workspace_id_2, workspace_key_2, "workspace_2")
    print("####"*15 + "Verifying Agent for the Second Workspace" + "####"*15)
    verify_msg_2 = verify_data(2, workspace_id_2)
    print("####"*15 + "Verifying Agent again for the First Workspace" + "####"*15)
    print("-----"*15 + "Injecting logs again for workspace 1" + "----"*15)
    for image in images:
        container = image + "-container"
        inject_logs(container, workspace_id_1, "workspace_1")
    current_time = datetime.now()
    while datetime.now() < (current_time + timedelta(minutes=DEFAULT_DELAY)):
            mins, secs = get_time_diff(datetime.now(), current_time + timedelta(minutes=DEFAULT_DELAY))
            sys.stdout.write('\rE2E propagation delay for {0}: {1} minutes {2} seconds...'.format(image, mins, secs))
            sys.stdout.flush()
            sleep(1)
    verify_msg_3 = verify_data(1, workspace_id_1)
    ## update_configs
    ## verify_data()
    # remove_msg = remove_agent()
    
    if is_long:
        for i in reversed(range(1, LONG_DELAY + 1)):
            sys.stdout.write('\rLong-term delay: T-{} minutes...'.format(i))
            sys.stdout.flush()
            sleep(60)
        print('')
        install_times.clear()
        for image in images:
            install_times.update({image: datetime.now()})
            container = image + '-container'
            inject_logs(container)
        long_verify_msg_1 = verify_data(1, workspace_id_1)
        long_verify_msg_2 = verify_data(2, workspace_id_2)

    else:
        long_verify_msg_1, long_verify_msg_2 = None, None

    purge_delete_agent(workspace_id_1)
    create_report(install_msg, onboard_2_msg, verify_msg_1, verify_msg_2, verify_msg_3, long_verify_msg_1, long_verify_msg_2)
    mv_result_files()

def install_agent(oms_bundle, workspace_id, workspace_key, workspace_dir):
    """Run container and install the OMS agent, returning HTML results."""
    message = ""
    version = re.search(r'omsagent-\s*([\d.\d-]+)', oms_bundle).group(1)
    install_times.clear()
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
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -preinstall {1}".format(container, workspace_id))
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --purge | tee -a {2}".format(container, oms_bundle, image+'temp.log'))
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --upgrade -w {2} -s {3} | tee -a {4}".format(container, oms_bundle, workspace_id, workspace_key, image+'temp.log'))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -postinstall {1} {2}".format(container, workspace_id, workspace_dir))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status {1}".format(container, workspace_id))
        install_times.update({image: datetime.now()})
        print ("injecting logs now")
        inject_logs(container, workspace_id, workspace_dir)
        append_file(image+'temp.log', log_file)
        os.remove(image+'temp.log')
        os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
        write_log_command("Create Container and Install OMS Agent v{0}".format(version), log_file)
        append_file('omsfiles/omsresults.out', log_file)
        os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
        html_file.write("<h2> Install OMS Agent v{0} </h2>".format(version))
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

def onboard_agent(workspace_id, workspace_key, workspace_dir):
    """ Run the oboard command in the container to onboard agent to a particular workspace id"""
    message = ""
    install_times.clear()
    version = re.search(r'omsagent-\s*([\d.\d-]+)', oms_bundle).group(1)
    for image in images:
        container = image + "-container"
        log_path = image + "result.log"
        html_path = image + "result.html"
        log_file = open(log_path, 'a+')
        html_file = open(html_path, 'a+')
        write_log_command("Container: {0}".format(container), log_file)
        write_log_command("Onboard Logs: {0}".format(image), log_file)
        os.system("docker exec {0} cp /home/temp/omsfiles/omsadmin.sh /opt/microsoft/omsagent/bin/ ".format(container))
        os.system("docker exec {0} cp /home/temp/omsfiles/service_control /opt/microsoft/omsagent/bin/ ".format(container))
        os.system("docker exec {0} sh /opt/microsoft/omsagent/bin/omsadmin.sh  -w {1} -s {2} | tee -a {3} ".format(container, workspace_id, workspace_key,  image+'temp.log'))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -multihome {1} {2}".format(container, workspace_id, workspace_dir))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status {1}".format(container, workspace_id))
        install_times.update({image: datetime.now()})
        inject_logs(container, workspace_id, workspace_dir)
        append_file(image+'temp.log', log_file)
        os.remove(image+'temp.log')

        os.system("docker cp {0}:/home/temp/omsresults.out omsfiles/".format(container))
        write_log_command("Multihome OMS Agent to Workspace -{0}".format(workspace_id), log_file)
        append_file('omsfiles/omsresults.out', log_file)
        os.system("docker cp {0}:/home/temp/omsresults.html omsfiles/".format(container))
        html_file.write("<h2> Multihome OMS Agent to Workspace -{0} </h2>".format(workspace_id))
        append_file('omsfiles/omsresults.html', html_file)
        log_file.close()
        html_file.close()

        if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
            x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
            if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
                message += """<td><span style='background-color: #66ff99'>Onboard Success</span></td>"""
            elif x_out.rstrip() == "No Workspace":
                message += """<td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
        else:
            message += """<td><span style='background-color: red; color: white'>No Prior Installation Found</span></td>"""

    return message
    
def inject_logs(container, workspace_id, workspace_dir):
    """Inject logs."""
    sleep(60)
    os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -injectlogs {1} {2}".format(container, workspace_id, workspace_dir))
        
def verify_data(ws_num, workspace_id):
    """Verify data end-to-end, returning HTML results."""

    message = ""
    for hostname in hostnames:
        image = hostname.split('-')[0]
        log_path = image + "result.log"
        html_path = image + "result.html"
        log_file = open(log_path, 'a+')
        html_file = open(html_path, 'a+')
        while datetime.now() < (install_times[image] + timedelta(minutes=DEFAULT_DELAY)):
            mins, secs = get_time_diff(datetime.now(), install_times[image] + timedelta(minutes=DEFAULT_DELAY))
            sys.stdout.write('\rE2E propagation delay for {0}: {1} minutes {2} seconds...'.format(image, mins, secs))
            sys.stdout.flush()
            sleep(1)
        print('')
        minutes, _ = get_time_diff(install_times[image], datetime.now())
        timespan = 'PT{0}M'.format(minutes)
        data = check_e2e(hostname, ws_num, timespan)

        # write detailed table for image
        html_file.write("<h2> Verify Data from OMS workspace {0} </h2>".format(workspace_id))
        write_log_command('Status After Verifying Data', log_file)
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

def purge_delete_agent(workspace_id):
    """Purge the OMS agent and delete container."""
    for image in images:
        container = image + "-container"
        log_path = image + "result.log"
        omslog_path = image + "-omsagent.log"
        log_file = open(log_path, 'a+')
        oms_file = open(omslog_path, 'a+')
        write_log_command('\n OmsAgent Logs: Before Purging the agent\n', oms_file)
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -copyomslogs {1}".format(container, workspace_id))
        os.system("docker cp {0}:/home/temp/copyofomsagent.log omsfiles/".format(container))
        append_file('omsfiles/copyofomsagent.log', oms_file)
        write_log_command("Purge Logs: {0}".format(image), log_file)
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --purge | tee -a {2}".format(container, oms_bundle, image+'temp.log'))
        append_file(image+'temp.log', log_file)
        os.remove(image+'temp.log')
        oms_file.close()
        append_file(omslog_path, log_file)
        log_file.close()
        os.system("docker container stop {0}".format(container))
        os.system("docker container rm {0}".format(container))

def create_report(install_msg, onboard_2_msg, verify_msg_1, verify_msg_2, verify_msg_3, long_verify_msg, long_status_msg):
    """Compile the final HTML report."""
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
          <td>Long-Term Verify Data</td>
          {0}
        </tr>
        <tr>
          <td>Long-Term Status</td>
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
        <td>Install OMSAgent to Workspace #1</td>
        {1}
      </tr>
      <tr>
        <td>Verify Data Workspace #1</td>
        {2}
      </tr>
      <tr>
        <td>Onboard OMSAgent to Workspace #2</td>
        {3}
      </tr>
      <tr>
        <td>Verify Data Workspace #2</td>
        {4}
      </tr>
      <tr>
        <td>Verify Data Workspace #1</td>
        {5}
      </tr>
     {6}
      <tr>
        <td>Result Link</td>
        {7}
      <tr>
    </table>
    """.format(imagesth, install_msg, verify_msg_1, onboard_2_msg, verify_msg_2, verify_msg_3, long_running_summary, resultsth)
    result_html_file.write(statustable)

    # Create final html & log file
    for image in images:
        append_file(image + "result.log", result_log_file)
        append_file(image + "result.html", result_html_file)
    
    result_log_file.close()
    htmlend = """
    </body>
    </html>
    """
    result_html_file.write(htmlend)
    result_html_file.close()

def mv_result_files():
    if not os.path.exists('results'):
        os.makedirs('results')

    file_types = ['*result.*', '*-omsagent.log']
    for files in file_types:
        for f in glob(files):
            shutil.move(os.path.join(f), os.path.join('results/'))

if __name__ == '__main__':
    main()
