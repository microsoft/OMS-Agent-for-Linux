"""
Test the OMS Agent on all or a subset of images.

Setup: read parameters and setup HTML report
Test:
1. Create container and install agent
2. Wait for data to propagate to backend and check for data
?. Repeat steps 1 and 2 with newer agent
3. Remove agent
4. Reinstall agent
?. Optionally, wait for hours and check data and agent status
5. Purge agent and delete container
Finish: compile HTML report and log file
"""

import argparse
import atexit
import json
import os
import subprocess
import re
import shutil
import sys
from collections import OrderedDict
from datetime import datetime, timedelta
from glob import glob
from time import sleep

from json2html import *
from verify_e2e import check_e2e

E2E_DELAY = 10 # Delay (minutes) before checking for data
images = ["ubuntu14", "ubuntu16", "ubuntu18", "debian8", "debian9", "centos6", "centos7", "oracle6", "oracle7"]
hostnames = []
install_times = {}
procs = {}

example_text = """examples:
  $ python -u oms_docker_tests.py\t\t\tall images
  $ python -u oms_docker_tests.py -i -p\t\t\tall images, in parallel, with instant upgrade
  $ python -u oms_docker_tests.py -p -l 120\t\tall images, in parallel, long mode with length specified
  $ python -u oms_docker_tests.py image1 image2 ...\tsubset of images
"""

parser = argparse.ArgumentParser(epilog=example_text, formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument('-p', '--parallel', action='store_true', help='test distros in parallel')
parser.add_argument('-l', '--long', nargs='?', type=int, const=250, default=0, help='add a long wait in minutes followed by a second verification (default: 250)')
parser.add_argument('-i', '--instantupgrade', action='store_true', help='test upgrade on top of old bundle')
parser.add_argument('distros', nargs='*', default=images, help='list of distros to test (default: all)')
args = parser.parse_args()
images =  [i for i in args.distros if i in images]
invalid = [i for i in args.distros if i not in images]

if invalid:
    print('invalid distro(s): {0}. continuing ...'.format(invalid))

with open('{0}/parameters.json'.format(os.getcwd()), 'r') as f:
    parameters = f.read()
    if re.search(r'"<.*>"', parameters):
        print('Please replace placeholders in parameters.json')
        exit()
    parameters = json.loads(parameters)

try:
    if parameters['oms bundle'] and os.path.isfile('omsfiles/'+parameters['oms bundle']):
        oms_bundle = parameters['oms bundle']

    if parameters['old oms bundle'] and os.path.isfile('omsfiles/'+parameters['old oms bundle']):
        old_oms_bundle = parameters['old oms bundle']

except KeyError:
    print('parameters not defined correctly or omsbundle file not found')

workspace_id = parameters['workspace id']
workspace_key = parameters['workspace key']

def append_file(src, dest):
    """Append contents of src to dest."""
    f = open(src, 'r')
    dest.write(f.read())
    f.close()

def copy_append_remove(container, image, src, dest):
    """Copy file from docker container, append it to the specified destination, and delete it"""
    os.system("docker cp {0}:/home/temp/{1} results/{2}/".format(container, src, image))
    append_file('results/{0}/{1}'.format(image, src), dest)
    os.remove('results/{0}/{1}'.format(image, src))

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

def setup_vars(image):
    """Set up variables and open necessary log files for a generalized test operation."""
    container = image + '-container'
    log_path = 'results/{0}/result.log'.format(image)
    html_path = 'results/{0}/result.html'.format(image)
    omslog_path = 'results/{0}/omsagent.log'.format(image)
    tmp_path = 'results/{0}/temp.log'.format(image)
    log_file = open(log_path, 'a+')
    html_file = open(html_path, 'a+')
    oms_file = open(omslog_path, 'a+')
    return container, log_path, html_path, omslog_path, tmp_path, log_file, html_file, oms_file

def close_files(*args):
    for f in args:
        f.close()

# TODO this should be elsewhere/def'd
for image in images:
    path = 'results/{0}'.format(image)
    if not os.path.isdir('results/{0}'.format(image)):
        os.mkdir(path)

subfolder = '{}/'.format(images[0]) if len(images) == 1 or args.parallel else ''
result_html_file = open('results/{0}finalresult.html'.format(subfolder), 'a+')
result_log_file = open('results/{0}finalresult.log'.format(subfolder), 'a+')

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

    if args.parallel:
        print('Running tests in parallel. Progress will be hidden. Final report will generated for each distro individually')
        for image in images:
            flags = ' '.join([a for a in sys.argv if a.startswith('-') and a not in ['-p', '--parallel']])
            cmd = 'python -u {0} {1} {2}'.format(sys.argv[0], flags, image).split()
            with open(os.devnull, 'wb') as devnull:
                procs[image] = subprocess.Popen(cmd, stdout=devnull, stderr=devnull, env={'SUBPROCESS': 'true'})
        done = False
        elapsed_time = 0
        while not done:
            status = []
            status_msg = '\rStatus after {0} minutes ['.format(elapsed_time)
            for p in procs.items():
                status.append(p[1].poll())
                status_msg += ' {0}: {1},'.format(p[0], 'running' if status[-1] is None else status[-1])
            sys.stdout.write(status_msg[:-1] + ' ]')
            sys.stdout.flush()
            done = True if None not in status else False
            sleep(60)
            elapsed_time += 1
        print('\nFinished!')
    else:
        if args.instantupgrade:
            if not old_oms_bundle:
                print('Instant upgrade specified but no old oms bundle provided. Check parameters.json and omsfiles directory for bundle file existence')
                sys.exit(0)
            install_msg = install_agent(old_oms_bundle)
            verify_msg = verify_data()
            instantupgrade_install_msg = upgrade_agent(oms_bundle)
            instantupgrade_verify_msg = verify_data()
        else:
            install_msg = install_agent(oms_bundle)
            verify_msg = verify_data()
            instantupgrade_install_msg, instantupgrade_verify_msg = None, None

        remove_msg = remove_agent()
        reinstall_msg = reinstall_agent()
        if args.long:
            for i in reversed(range(1, args.log + 1)):
                sys.stdout.write('\rLong-term delay: T-{0} minutes...'.format(i))
                sys.stdout.flush()
                sleep(60)
            print('')
            install_times.clear()
            for image in images:
                install_times.update({image: datetime.now()})
                container = image + '-container'
                inject_logs(container)
            long_verify_msg = verify_data()
            long_status_msg = check_status()
        else:
            long_verify_msg, long_status_msg = None, None
        purge_delete_agent()
        messages = (install_msg, verify_msg, instantupgrade_install_msg, instantupgrade_verify_msg, remove_msg, reinstall_msg, long_verify_msg, long_status_msg)
        create_report(messages)

def install_agent(oms_bundle):
    """Run container and install the OMS agent, returning HTML results."""
    message = ""
    version = re.search(r'omsagent-\s*([\d.\d-]+)', oms_bundle).group(1)
    install_times.clear()
    for image in images:
        container, _, _, _, tmp_path, log_file, html_file, oms_file = setup_vars(image)
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
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --purge | tee -a {2}".format(container, oms_bundle, tmp_path))
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --upgrade -w {2} -s {3} | tee -a {4}".format(container, oms_bundle, workspace_id, workspace_key, tmp_path))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
        install_times.update({image: datetime.now()})
        inject_logs(container)
        append_file(tmp_path, log_file)
        os.remove(tmp_path)
        write_log_command("Create Container and Install OMS Agent v{0}".format(version), log_file)
        copy_append_remove(container, image, 'omsresults.out', log_file)
        html_file.write("<h2> Install OMS Agent v{0} </h2>".format(version))
        copy_append_remove(container, image, 'omsresults.html', html_file)
        close_files(log_file, html_file, oms_file)
        if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
            x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
            if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
                message += """<td><span style='background-color: #66ff99'>Install Success</span></td>"""
            elif x_out.rstrip() == "No Workspace":
                message += """<td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
        else:
            message += """<td><span style='background-color: red; color: white'>Install Failed</span></td>"""
    return message

def upgrade_agent(oms_bundle):
    message = ""
    version = re.search(r'omsagent-\s*([\d.\d-]+)', oms_bundle).group(1)
    install_times.clear()
    for image in images:
        container, _, _, _, tmp_path, log_file, html_file, oms_file = setup_vars(image)
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --upgrade -w {2} -s {3} | tee -a {4}".format(container, oms_bundle, workspace_id, workspace_key, tmp_path))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
        install_times.update({image: datetime.now()})
        inject_logs(container)
        append_file(tmp_path, log_file)
        os.remove(tmp_path)
        write_log_command("Upgrade OMS Agent v{0}".format(version), log_file)
        copy_append_remove(container, image, 'omsresults.out', log_file)
        html_file.write("<h2> Upgrade OMS Agent v{0} </h2>".format(version))
        copy_append_remove(container, image, 'omsresults.html', html_file)
        close_files(log_file, html_file, oms_file)
        if os.system('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container)) == 0:
            x_out = subprocess.check_output('docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -l'.format(container), shell=True)
            if re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x_out).group(0) == workspace_id:
                message += """<td><span style='background-color: #66ff99'>Install Success</span></td>"""
            elif x_out.rstrip() == "No Workspace":
                message += """<td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
        else:
            message += """<td><span style='background-color: red; color: white'>Install Failed</span></td>"""
    return message

def inject_logs(container):
    """Inject logs."""
    sleep(60)
    os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -injectlogs".format(container))
        
def verify_data():
    """Verify data end-to-end, returning HTML results."""
    message = ""
    for hostname in hostnames:
        image = hostname.split('-')[0]
        log_path = 'results/{}/result.log'.format(image)
        html_path = 'results/{}/result.html'.format(image)
        log_file = open(log_path, 'a+')
        html_file = open(html_path, 'a+')
        while datetime.now() < (install_times[image] + timedelta(minutes=E2E_DELAY)):
            mins, secs = get_time_diff(datetime.now(), install_times[image] + timedelta(minutes=E2E_DELAY))
            sys.stdout.write('\rE2E propagation delay for {0}: {1} minutes {2} seconds...'.format(image, mins, secs))
            sys.stdout.flush()
            sleep(1)
        print('')
        minutes, _ = get_time_diff(install_times[image], datetime.now())
        timespan = 'PT{0}M'.format(minutes)
        data = check_e2e(hostname, timespan)

        # write detailed table for image
        html_file.write("<h2> Verify Data from OMS workspace </h2>")
        write_log_command('Status After Verifying Data', log_file)
        results = data[image][0]
        log_file.write(image + ':\n' + json.dumps(results, indent=4, separators=(',', ': ')) + '\n')
        # prepend distro column to results row before generating the table
        data = [OrderedDict([('Distro', image)] + results.items())]
        out = json2html.convert(data)
        html_file.write(out)
        close_files(log_file, html_file)

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
        container, _, _, _, tmp_path, log_file, html_file, oms_file = setup_vars(image)
        write_log_command('\n OmsAgent Logs: Before Removing the agent\n', oms_file)
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -copyomslogs".format(container))
        copy_append_remove(container, image, 'copyofomsagent.log', oms_file)
        write_log_command("Remove Logs: {0}".format(image), log_file)
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --remove | tee -a {2}".format(container, oms_bundle, tmp_path))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
        append_file(tmp_path, log_file)
        os.remove(tmp_path)
        write_log_command("Remove OMS Agent", log_file)
        copy_append_remove(container, image, 'omsresults.out', log_file)
        html_file.write("<h2> Remove OMS Agent </h2>")
        copy_append_remove(container, image, 'omsresults.html', html_file)
        close_files(log_file, html_file, oms_file)
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
        container, _, _, _, tmp_path, log_file, html_file, oms_file = setup_vars(image)
        write_log_command("Reinstall Logs: {0}".format(image), log_file)
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --upgrade | tee -a {2}".format(container, oms_bundle, tmp_path))
        os.system("docker exec {0} /opt/microsoft/omsagent/bin/omsadmin.sh -w {1} -s {2} | tee -a {3}".format(container, workspace_id, workspace_key, tmp_path))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -postinstall".format(container))
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
        append_file(tmp_path, log_file)
        os.remove(tmp_path)
        write_log_command("Reinstall OMS Agent", log_file)
        copy_append_remove(container, image, 'omsresults.out', log_file)
        html_file.write("<h2> Reinstall OMS Agent </h2>")
        copy_append_remove(container, image, 'omsresults.html', html_file)
        close_files(log_file, html_file, oms_file)
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
        container, _, _, _, _, log_file, html_file, oms_file = setup_vars(image)
        write_log_command("Check Status: {0}".format(image), log_file)
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -status".format(container))
        copy_append_remove(container, image, 'omsresults.out', log_file)
        html_file.write("<h2> Check OMS Agent Status </h2>")
        copy_append_remove(container, image, 'omsresults.html', html_file)
        close_files(log_file, html_file, oms_file)
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
        container, _, _, omslog_path, tmp_path, log_file, html_file, oms_file = setup_vars(image)
        write_log_command('\n OmsAgent Logs: Before Purging the agent\n', oms_file)
        os.system("docker exec {0} python -u /home/temp/omsfiles/oms_run_script.py -copyomslogs".format(container))
        copy_append_remove(container, image, 'copyofomsagent.log', oms_file)
        write_log_command("Purge Logs: {0}".format(image), log_file)
        os.system("docker exec {0} sh /home/temp/omsfiles/{1} --purge | tee -a {2}".format(container, oms_bundle, tmp_path))
        append_file(tmp_path, log_file)
        os.remove(tmp_path)
        append_file(omslog_path, log_file)
        close_files(log_file, html_file, oms_file)
        os.system("docker container stop {0}".format(container))
        os.system("docker container rm {0}".format(container))

def create_report(messages):
    """Compile the final HTML report."""
    install_msg, verify_msg, instantupgrade_install_msg, instantupgrade_verify_msg, remove_msg, reinstall_msg, long_verify_msg, long_status_msg = messages

    # summary table
    imagesth = ""
    resultsth = ""
    for image in images:
        imagesth += """
                <th>{0}</th>""".format(image)
        resultsth += """
                <th><a href='#{0}'>{0} results</a></th>""".format(image)

    # pre-compile instant-upgrade summary
    if instantupgrade_install_msg and instantupgrade_verify_msg:
        instantupgrade_summary = """
        <tr>
          <td>Instant Upgrade Install Status</td>
          {0}
        </tr>
        <tr>
          <td>Instant Upgrade Verify Data</td>
          {1}
        </tr>
        """.format(instantupgrade_install_msg, instantupgrade_verify_msg)
    else:
        instantupgrade_summary = ""

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
        <td>Install OMSAgent</td>
        {1}
      </tr>
      <tr>
        <td>Verify Data</td>
        {2}
      </tr>
      {3}
      <tr>
        <td>Remove OMSAgent</td>
        {4}
      </tr>
      <tr>
        <td>Reinstall OMSAgent</td>
        {5}
      </tr>
      {6}
      <tr>
        <td>Result Link</td>
        {7}
      <tr>
    </table>
    """.format(imagesth, install_msg, verify_msg, instantupgrade_summary, remove_msg, reinstall_msg, long_running_summary, resultsth)
    result_html_file.write(statustable)

    # Create final html & log file
    for image in images:
        append_file('results/{}/result.log'.format(image), result_log_file)
        append_file('results/{}/result.html'.format(image), result_html_file)
    
    result_log_file.close()
    htmlend = """
    </body>
    </html>
    """
    result_html_file.write(htmlend)
    result_html_file.close()

def archive_results():
    archive_path = 'results/' + datetime.now().strftime('%Y-%m-%d %H.%M.%S')
    os.mkdir(archive_path)
    for f in [f for f in glob('results/*') if f.split('/')[1] in images or f.startswith('results/finalresult') ]:
        shutil.move(os.path.join(f), os.path.join(archive_path))

def cleanup():
    sys.stdout.write('Initiating cleanup\n')
    sys.stdout.flush()
    archive_results()
    for p in procs.items():
        if p[1].poll() is None:
            p[1].kill()
    for image in images:
        container = image + '-container'
        os.system('docker kill {} 2> /dev/null'.format(container))
    sleep(1)
    sys.exit(0)

if __name__ == '__main__':
    if not os.environ.get('SUBPROCESS'):
        atexit.register(cleanup)
    main()
