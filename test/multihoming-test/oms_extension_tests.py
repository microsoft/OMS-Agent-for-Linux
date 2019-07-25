"""
Test the OMS Agent's multihoming feature on ubuntu.

Setup: read parameters and setup HTML report
Test:
1. Create vm and install agent onboarded to just one workspace
2. Wait for data to propagate to backend and check for data on WS #1
3. Onboard to another workspace
4. Wait for data to propagate to backend and check for data on WS #2
5. Make changes to the configs for WS #1 and #2 and check for data from that.
6. Purge extension and delete vm
Finish: compile HTML report and log file
"""

import json
import os
import os.path
import subprocess
import re
import sys
import rstr
import glob
import shutil

from time import sleep
from datetime import datetime, timedelta
from platform import system
from collections import OrderedDict
from verify_e2e import check_e2e

from json2html import *

DEFAULT_DELAY = 15 # Delay (minutes) before checking for data
AUTOUPGRADE_DELAY = 15 # Delay (minutes) before rechecking the extension version
LONG_DELAY = 250 # Delay (minutes) before rechecking extension

images_list = { #'ubuntu14': 'Canonical:UbuntuServer:14.04.5-LTS:14.04.201808180',
        #  'ubuntu16': 'Canonical:UbuntuServer:16.04-LTS:latest',
         'ubuntu18': 'Canonical:UbuntuServer:18.04-LTS:latest',
        #  'debian8': 'credativ:Debian:8:latest',
        #  'debian9': 'credativ:Debian:9:latest',
        #  'redhat6': 'RedHat:RHEL:6.9:latest',
        #  'redhat7': 'RedHat:RHEL:7.3:latest',
        #  'centos6': 'OpenLogic:CentOS:6.9:latest',
        #  'centos7': 'OpenLogic:CentOS:7.5:latest',
         # 'oracle6': 'Oracle:Oracle-Linux:6.9:latest',
        #  'oracle7': 'Oracle:Oracle-Linux:7.5:latest',
        #  'sles12': 'SUSE:SLES:12-SP3:latest',
        #  'sles15': 'SUSE:SLES:15:latest'}

vmnames = []
images = {}
install_times = {}

runwith = '--verbose'

vms_list = []
if len(sys.argv) > 0:
    options = sys.argv[1:]
    vms_list = [ i for i in options if i not in ('long', 'debug')]
    is_long = 'long' in options
    runwith = '--debug' if 'debug' in options else '--verbose'
else:
    is_long = is_debug = False

if vms_list:
    for vm in vms_list:
        vm_dict = { vm: images_list[vm] }
        images.update(vm_dict)
else:
    images = images_list

print("List of VMs & Image Sources added for testing: {}".format(images))

with open('{0}/parameters.json'.format(os.getcwd()), 'r') as f:
    parameters = f.read()
    if re.search(r'"<.*>"', parameters):
        print('Please replace placeholders in parameters.json')
        exit()
    parameters = json.loads(parameters)

resource_group = parameters['resource group']
location = parameters['location']
username = parameters['username']
nsg = parameters['nsg']
nsg_resource_group = parameters['nsg resource group']
size = parameters['size'] # Preferred: 'Standard_B1ms'
extension = 'OmsAgentForLinux'
publisher = 'Microsoft.EnterpriseCloud.Monitoring'
key_vault = parameters['key vault']
subscription = str(json.loads(subprocess.check_output('az keyvault secret show --name subscription-id --vault-name {0}'.format(key_vault), shell=True))["value"])
workspace_id = str(json.loads(subprocess.check_output('az keyvault secret show --name workspace-id --vault-name {0}'.format(key_vault), shell=True))["value"])
workspace_key = str(json.loads(subprocess.check_output('az keyvault secret show --name workspace-key --vault-name {0}'.format(key_vault), shell=True))["value"])
public_settings = { "workspaceId": workspace_id }
private_settings = { "workspaceKey": workspace_key }
nsg_uri = "/subscriptions/" + subscription + "/resourceGroups/" + nsg_resource_group + "/providers/Microsoft.Network/networkSecurityGroups/" + nsg
ssh_private = parameters['ssh private']
ssh_public = ssh_private + '.pub'
if parameters['old version']:
    old_version = parameters['old version']

# Sometimes Azure VM images become unavailable or are unavailable in certain regions, lets check...
for distname, image in images.iteritems():
    img_publisher, _, sku, _ = image.split(':')
    if subprocess.check_output('az vm image list --all --location {0} --publisher {1} --sku {2}'.format(location, img_publisher, sku), shell=True) == '[]\n':
        print('Could not find image for {0} in {1}, please double check VM image availability'.format(distname, location))
        exit()
    else:
        print('VM image availability successfully validated')

# Detect the host system and validate nsg
if system() == 'Windows':
    if os.system('az network nsg show --resource-group {0} --name {1} --query "[?n]"'.format(nsg_resource_group, nsg)) == 0:
        print("Network Security Group successfully validated")
elif system() == 'Linux':
    if os.system('az network nsg show --resource-group {0} --name {1} > /dev/null 2>&1'.format(nsg_resource_group, nsg)) == 0:
        print("Network Security Group successfully validated")
else:
    print("""Please verify that the nsg or nsg resource group are valid and are in the right subscription.
If there is no Network Security Group, please create new one. NSG is a must to create a VM in this testing.""")
    exit()

# Remove intermediate log and html files
os.system('rm -rf ./*.log ./*.html ./results 2> /dev/null')

result_html_file = open("finalresult.html", 'a+')

# Common logic to save command itself
def write_log_command(log, cmd):
    print(cmd)
    log.write(cmd + '\n')
    log.write('-' * 40)
    log.write('\n')

# Common logic to append a file to another
def append_file(src, dest):
    f = open(src, 'r')
    dest.write(f.read())
    f.close()

# Get time difference in minutes and seconds
def get_time_diff(timevalue1, timevalue2):
    timediff = timevalue2 - timevalue1
    minutes, seconds = divmod(timediff.days * 86400 + timediff.seconds, 60)
    return minutes, seconds

# Secure copy required files from local to vm
def copy_to_vm(dnsname, username, ssh_private, location):
    os.system("scp -i {0} -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -r omsfiles/* {1}@{2}.{3}.cloudapp.azure.com:/tmp/".format(ssh_private, username, dnsname.lower(), location))

# Secure copy files from vm to local
def copy_from_vm(dnsname, username, ssh_private, location, filename):
    os.system("scp -i {0} -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -r {1}@{2}.{3}.cloudapp.azure.com:/home/scratch/{4} omsfiles/.".format(ssh_private, username, dnsname.lower(), location, filename))

# Run scripts on vm using AZ CLI
def run_command(resource_group, vmname, commandid, script):
    os.system('az vm run-command invoke -g {0} -n {1} --command-id {2} --scripts "{3}" {4}'.format(resource_group, vmname, commandid, script, runwith))

# Create vm using AZ CLI
def create_vm(resource_group, vmname, image, username, ssh_public, location, dnsname, vmsize, nsg_uri):
    os.system('az vm create -g {0} -n {1} --image {2} --admin-username {3} --ssh-key-value @{4} --location {5} --public-ip-address-dns-name {6} --size {7} --nsg {8} {9}'.format(resource_group, vmname, image, username, ssh_public, location, dnsname, vmsize, nsg_uri, runwith))

# Add extension to vm using AZ CLI
def add_extension(extension, publisher, vmname, resource_group, private_settings, public_settings, update_option):
    os.system('az vm extension set -n {0} --publisher {1} --vm-name {2} --resource-group {3} --protected-settings "{4}" --settings "{5}" {6} {7}'.format(extension, publisher, vmname, resource_group, private_settings, public_settings, update_option, runwith))

# Delete extension from vm using AZ CLI
def delete_extension(extension, vmname, resource_group):
    os.system('az vm extension delete -n {0} --vm-name {1} --resource-group {2} {3}'.format(extension, vmname, resource_group, runwith))

# Get vm details using AZ CLI
def get_vm_resources(resource_group, vmname):
    vm_cli_out = json.loads(subprocess.check_output('az vm show -g {0} -n {1}'.format(resource_group, vmname), shell=True))
    os_disk = vm_cli_out['storageProfile']['osDisk']['name']
    nic_name = vm_cli_out['networkProfile']['networkInterfaces'][0]['id'].split('/')[-1]
    ip_list = json.loads(subprocess.check_output('az vm list-ip-addresses -n {0} -g {1}'.format(vmname, resource_group), shell=True))
    ip_name = ip_list[0]['virtualMachine']['network']['publicIpAddresses'][0]['name']
    return os_disk, nic_name, ip_name

def get_extension_version_now(resource_group, vmname, extension):
    vm_ext_out = json.loads(subprocess.check_output('az vm extension show --resource-group {0} --vm-name {1} --name {2} --expand instanceView'.format(resource_group, vmname, extension), shell=True))
    installed_version = int(('').join(str(vm_ext_out["instanceView"]["typeHandlerVersion"]).split('.')))
    return installed_version

# Delete vm using AZ CLI
def delete_vm(resource_group, vmname):
    os.system('az vm delete -g {0} -n {1} --yes {2}'.format(resource_group, vmname, runwith))

# Delete vm disk using AZ CLI
def delete_vm_disk(resource_group, os_disk):
    os.system('az disk delete --resource-group {0} --name {1} --yes {2}'.format(resource_group, os_disk, runwith))

# Delete vm network interface using AZ CLI
def delete_nic(resource_group, nic_name):
    os.system('az network nic delete --resource-group {0} --name {1} --no-wait {2}'.format(resource_group, nic_name, runwith))

# Delete vm ip from AZ CLI
def delete_ip(resource_group, ip_name):
    os.system('az network public-ip delete --resource-group {0} --name {1} {2}'.format(resource_group, ip_name, runwith))


htmlstart = """<!DOCTYPE html>
<html>
<head>
<style>
table {
    font-family: arial, sans-serif;
    border-collapse: collapse;
    width: 100%;
}

table:not(th) {
    font-weight: lighter;
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
    if is_instantupgrade:
        install_oms_msg = create_vm_and_install_old_extension()
        verify_oms_msg = verify_data()
        instantupgrade_status_msg = force_upgrade_extension()
        instantupgrade_verify_msg = verify_data()
    else:
        instantupgrade_verify_msg, instantupgrade_status_msg = None, None
        install_oms_msg = create_vm_and_install_extension()
        verify_oms_msg = verify_data()

    if is_autoupgrade:
        autoupgrade_status_msg = autoupgrade()
        autoupgrade_verify_msg = verify_data()
    else:
        autoupgrade_verify_msg, autoupgrade_status_msg = None, None
    
    remove_oms_msg = remove_extension()
    reinstall_oms_msg = reinstall_extension()
    if is_long:
        for i in reversed(range(1, LONG_DELAY + 1)):
            sys.stdout.write('\rLong-term delay: T-{0} minutes...'.format(i))
            sys.stdout.flush()
            sleep(60)
        print('')
        long_status_msg = check_status()
        long_verify_msg = verify_data()
    else:
        long_verify_msg, long_status_msg = None, None
    remove_extension_and_delete_vm()
    messages = (install_oms_msg, verify_oms_msg, instantupgrade_verify_msg, instantupgrade_status_msg, autoupgrade_verify_msg, autoupgrade_status_msg, remove_oms_msg, reinstall_oms_msg, long_verify_msg, long_status_msg)
    create_report(messages)
    mv_result_files()


def create_vm_and_install_extension():
    """Create vm and install the extension, returning HTML results."""

    message = ""
    update_option = ""
    install_times.clear()
    for distname, image in images.iteritems():
        uid = rstr.xeger(r'[0-9a-f]{8}')
        vmname = distname.lower() + '-' + uid
        vmnames.append(vmname)
        dnsname = vmname
        vm_log_file = distname.lower() + "result.log"
        vm_html_file = distname.lower() + "result.html"
        log_open = open(vm_log_file, 'a+')
        html_open = open(vm_html_file, 'a+')
        print("\nCreate VM and Install Extension - {0}: {1} \n".format(vmname, image))
        create_vm(resource_group, vmname, image, username, ssh_public, location, dnsname, size, nsg_uri)
        copy_to_vm(dnsname, username, ssh_private, location)
        delete_extension(extension, vmname, resource_group)
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /tmp/oms_extension_run_script.py -preinstall')
        add_extension(extension, publisher, vmname, resource_group, private_settings, public_settings, update_option)
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -postinstall')
        install_times.update({vmname: datetime.now()})
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -injectlogs')
        copy_from_vm(dnsname, username, ssh_private, location, 'omsresults.*')
        write_log_command(log_open, 'Status After Creating VM and Adding OMS Extension')
        html_open.write('<h1 id="{0}"> VM: {0} <h1>'.format(distname))
        html_open.write("<h2> Install OMS Agent </h2>")
        append_file('omsfiles/omsresults.log', log_open)
        append_file('omsfiles/omsresults.html', html_open)
        log_open.close()
        html_open.close()
        status = open('omsfiles/omsresults.status', 'r').read()
        if status == "Agent Found":
            message += """
                            <td><span style='background-color: #66ff99'>Install Success</span></td>"""
        elif status == "Onboarding Failed":
            message += """
                            <td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
        elif status == "Agent Not Found":
            message += """
                            <td><span style='background-color: red; color: white'>Install Failed</span></td>"""
    return message

def create_vm_and_install_old_extension():
    """Create vm and install a specific version of the extension, returning HTML results."""

    message = ""
    update_option = '--version {0} --no-auto-upgrade'.format(old_version)
    install_times.clear()
    for distname, image in images.iteritems():
        uid = rstr.xeger(r'[0-9a-f]{8}')
        vmname = distname.lower() + '-' + uid
        vmnames.append(vmname)
        dnsname = vmname
        vm_log_file = distname.lower() + "result.log"
        vm_html_file = distname.lower() + "result.html"
        log_open = open(vm_log_file, 'a+')
        html_open = open(vm_html_file, 'a+')
        print("\nCreate VM and Install Extension {0} v-{1} - {2}: {3} \n".format(extension, old_version, vmname, image))
        create_vm(resource_group, vmname, image, username, ssh_public, location, dnsname, size, nsg_uri)
        copy_to_vm(dnsname, username, ssh_private, location)
        delete_extension(extension, vmname, resource_group)
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /tmp/oms_extension_run_script.py -preinstall')
        add_extension(extension, publisher, vmname, resource_group, private_settings, public_settings, update_option)
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -postinstall')
        install_times.update({vmname: datetime.now()})
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -injectlogs')
        copy_from_vm(dnsname, username, ssh_private, location, 'omsresults.*')
        write_log_command(log_open, "Status After Creating VM and Adding OMS Extension version: {0}".format(old_version))
        html_open.write('<h1 id="{0}"> VM: {0} <h1>'.format(distname))
        html_open.write("<h2> Install OMS Agent version: {0} </h2>".format(old_version))
        append_file('omsfiles/omsresults.log', log_open)
        append_file('omsfiles/omsresults.html', html_open)
        log_open.close()
        html_open.close()
        status = open('omsfiles/omsresults.status', 'r').read()
        if status == "Agent Found":
            message += """
                            <td><span style='background-color: #66ff99'>Install Success</span></td>"""
        elif status == "Onboarding Failed":
            message += """
                            <td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
        elif status == "Agent Not Found":
            message += """
                            <td><span style='background-color: red; color: white'>Install Failed</span></td>"""
    return message

def force_upgrade_extension():
    """ Force Update the extension to the latest version """

    message = ""
    update_option = '--force-update'
    install_times.clear()
    for vmname in vmnames:
        distname = vmname.split('-')[0]
        vm_log_file = distname + "result.log"
        vm_html_file = distname + "result.html"
        log_open = open(vm_log_file, 'a+')
        html_open = open(vm_html_file, 'a+')
        dnsname = vmname
        print("\n Force Upgrade Extension: {0} \n".format(vmname))
        add_extension(extension, publisher, vmname, resource_group, private_settings, public_settings, update_option)
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -postinstall')
        install_times.update({vmname: datetime.now()})
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -injectlogs')
        copy_from_vm(dnsname, username, ssh_private, location, 'omsresults.*')
        write_log_command(log_open, 'Status After Force Upgrading OMS Extension')
        html_open.write('<h2> Force Upgrade Extension: {0} <h2>'.format(vmname))
        append_file('omsfiles/omsresults.log', log_open)
        append_file('omsfiles/omsresults.html', html_open)
        log_open.close()
        html_open.close()
        status = open('omsfiles/omsresults.status').read()
        if status == "Agent Found":
            message += """
                            <td><span style='background-color: #66ff99'>Reinstall Success</span></td>"""
        elif status == "Onboarding Failed":
            message += """
                            <td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
        elif status == "Agent Not Found":
            message += """
                            <td><span style='background-color: red; color: white'>Reinstall Failed</span></td>"""
    return message

def verify_data():
    """Verify data end-to-end, returning HTML results."""

    message = ""
    for vmname in vmnames:
        distname = vmname.split('-')[0]
        vm_log_file = distname + "result.log"
        vm_html_file = distname + "result.html"
        log_open = open(vm_log_file, 'a+')
        html_open = open(vm_html_file, 'a+')
        
        # Delay to allow data to propagate
        while datetime.now() < (install_times[vmname] + timedelta(minutes=DEFAULT_DELAY)):
            mins, secs = get_time_diff(datetime.now(), install_times[vmname] + timedelta(minutes=DEFAULT_DELAY))
            sys.stdout.write('\rE2E propagation delay: {0} minutes {1} seconds...'.format(mins, secs))
            sys.stdout.flush()
            sleep(1)
        print('')
        minutes, _ = get_time_diff(install_times[vmname], datetime.now())
        timespan = 'PT{0}M'.format(minutes)
        data = check_e2e(vmname, timespan)

        # write detailed table for vm
        html_open.write("<h2> Verify Data from OMS workspace </h2>")
        write_log_command(log_open, 'Status After Verifying Data')
        results = data[distname][0]
        log_open.write(distname + ':\n' + json.dumps(results, indent=4, separators=(',', ': ')) + '\n')
        # prepend distro column to results row before generating the table
        data = [OrderedDict([('Distro', distname)] + results.items())]
        out = json2html.convert(data)
        html_open.write(out)

        # write to summary table
        from verify_e2e import success_count
        if success_count == 6:
            message += """
                            <td><span style='background-color: #66ff99'>Verify Success</td>"""
        elif 0 < success_count < 6:
            from verify_e2e import success_sources, failed_sources
            message += """
                            <td><span style='background-color: #66ff99'>{0} Success</span> <br><br><span style='background-color: red; color: white'>{1} Failed</span></td>""".format(', '.join(success_sources), ', '.join(failed_sources))
        elif success_count == 0:
            message += """
                            <td><span style='background-color: red; color: white'>Verify Failed</span></td>"""
    return message

def autoupgrade():
    """ Waits for the extension to get updated automatically and continues with the tests after. Maximum wait time is 26 hours """

    message = ""
    install_times.clear()
    for vmname in vmnames:
        initial_version = get_extension_version_now(resource_group, vmname, extension)
        time_lapsed = 0
        while initial_version >= get_extension_version_now(resource_group, vmname, extension):
            sleep(AUTOUPGRADE_DELAY*60)
            time_lapsed+=AUTOUPGRADE_DELAY
            if time_lapsed < 1440:
                sys.stdout.write("waiting for new version. Time Lapsed: {0} minutes".format(time_lapsed))
                sys.stdout.flush()
            elif 1440 <= time_lapsed < 1560:
                sys.stdout.write('Process waiting for more than 24 hrs. Please check the deployment of the new version is completed or not. This wait will end in {0} minutes'.format(1560 - time_lapsed))
                sys.stdout.flush()
            elif time_lapsed >= 1560:
                print("""Process waiting for more than 26 hrs. No New version of extension has been deployed.
                    If a new version is deployed, please check for any errors and re-run""")
                break

        distname = vmname.split('-')[0]
        vm_log_file = distname + "result.log"
        vm_html_file = distname + "result.html"
        log_open = open(vm_log_file, 'a+')
        html_open = open(vm_html_file, 'a+')
        dnsname = vmname
        print("\n Checking Status After AutoUpgrade: {0} \n".format(vmname))
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -postinstall')
        install_times.update({vmname: datetime.now()})
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -injectlogs')
        copy_from_vm(dnsname, username, ssh_private, location, 'omsresults.*')
        write_log_command(log_open, 'Status After AutoUpgrade OMS Extension')
        html_open.write('<h2> Status After AutoUpgrade OMS Extension: {0} <h2>'.format(vmname))
        append_file('omsfiles/omsresults.log', log_open)
        append_file('omsfiles/omsresults.html', html_open)
        log_open.close()
        html_open.close()
        status = open('omsfiles/omsresults.status').read()
        if status == "Agent Found":
            message += """
                            <td><span style='background-color: #66ff99'>AutoUpgrade Success</span></td>"""
        elif status == "Onboarding Failed":
            message += """
                            <td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
        elif status == "Agent Not Found":
            message += """
                            <td><span style='background-color: red; color: white'>AutoUpgrade Failed</span></td>"""
    return message

def remove_extension():
    """Remove the extension, returning HTML results."""

    message = ""
    for vmname in vmnames:
        distname = vmname.split('-')[0]
        vm_log_file = distname + "result.log"
        vm_html_file = distname + "result.html"
        log_open = open(vm_log_file, 'a+')
        html_open = open(vm_html_file, 'a+')
        dnsname = vmname
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -copyomslogs')
        print("\nRemove Extension: {0} \n".format(vmname))
        delete_extension(extension, vmname, resource_group)
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -status')
        copy_from_vm(dnsname, username, ssh_private, location, 'omsresults.*')
        write_log_command(log_open, 'Status After Removing OMS Extension')
        html_open.write('<h2> Remove Extension: {0} <h2>'.format(vmname))
        append_file('omsfiles/omsresults.log', log_open)
        append_file('omsfiles/omsresults.html', html_open)
        log_open.close()
        html_open.close()
        status = open('omsfiles/omsresults.status', 'r').read()
        if status == "Agent Found":
            message += """
                            <td><span style="background-color: red; color: white">Remove Failed</span></td>"""
        elif status == "Onboarding Failed":
            message += """
                            <td><span style="background-color: red; color: white">Onboarding Failed</span></td>"""
        elif status == "Agent Not Found":
            message += """
                            <td><span style="background-color: #66ff99">Remove Success</span></td>"""
    return message


def reinstall_extension():
    """Reinstall the extension, returning HTML results."""

    update_option = '--force-update'
    message = ""
    for vmname in vmnames:
        distname = vmname.split('-')[0]
        vm_log_file = distname + "result.log"
        vm_html_file = distname + "result.html"
        log_open = open(vm_log_file, 'a+')
        html_open = open(vm_html_file, 'a+')
        dnsname = vmname
        print("\n Reinstall Extension: {0} \n".format(vmname))
        add_extension(extension, publisher, vmname, resource_group, private_settings, public_settings, update_option)
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -postinstall')
        copy_from_vm(dnsname, username, ssh_private, location, 'omsresults.*')
        write_log_command(log_open, 'Status After Reinstall OMS Extension')
        html_open.write('<h2> Reinstall Extension: {0} <h2>'.format(vmname))
        append_file('omsfiles/omsresults.log', log_open)
        append_file('omsfiles/omsresults.html', html_open)
        log_open.close()
        html_open.close()
        status = open('omsfiles/omsresults.status').read()
        if status == "Agent Found":
            message += """
                            <td><span style='background-color: #66ff99'>Reinstall Success</span></td>"""
        elif status == "Onboarding Failed":
            message += """
                            <td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
        elif status == "Agent Not Found":
            message += """
                            <td><span style='background-color: red; color: white'>Reinstall Failed</span></td>"""
    return message

def check_status():
    """Check agent status."""

    message = ""
    install_times.clear()
    for vmname in vmnames:
        distname = vmname.split('-')[0]
        vm_log_file = distname + "result.log"
        vm_html_file = distname + "result.html"
        log_open = open(vm_log_file, 'a+')
        html_open = open(vm_html_file, 'a+')
        dnsname = vmname
        print("\n Checking Status: {0} \n".format(vmname))
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -status')
        install_times.update({vmname: datetime.now()})
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -injectlogs')
        copy_from_vm(dnsname, username, ssh_private, location, 'omsresults.*')
        write_log_command(log_open, 'Status After Long Run OMS Extension')
        html_open.write('<h2> Status After Long Run OMS Extension: {0} <h2>'.format(vmname))
        append_file('omsfiles/omsresults.log', log_open)
        append_file('omsfiles/omsresults.html', html_open)
        log_open.close()
        html_open.close()
        status = open('omsfiles/omsresults.status').read()
        if status == "Agent Found":
            message += """
                            <td><span style='background-color: #66ff99'>Reinstall Success</span></td>"""
        elif status == "Onboarding Failed":
            message += """
                            <td><span style='background-color: red; color: white'>Onboarding Failed</span></td>"""
        elif status == "Agent Not Found":
            message += """
                            <td><span style='background-color: red; color: white'>Reinstall Failed</span></td>"""
    return message

def remove_extension_and_delete_vm():
    """Remove extension and delete vm."""

    for vmname in vmnames:
        distname = vmname.split('-')[0]
        vm_log_file = distname + "result.log"
        log_open = open(vm_log_file, 'a+')
        dnsname = vmname
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -copyomslogs')
        copy_from_vm(dnsname, username, ssh_private, location, '{0}-omsagent.log'.format(distname))
        print("\n Remove extension and Delete VM: {0} \n".format(vmname))
        delete_extension(extension, vmname, resource_group)
        run_command(resource_group, vmname, 'RunShellScript', 'python -u /home/scratch/oms_extension_run_script.py -copyextlogs')
        copy_from_vm(dnsname, username, ssh_private, location, '{0}-extnwatcher.log'.format(distname))
        disk, nic, ip = get_vm_resources(resource_group, vmname)
        delete_vm(resource_group, vmname)
        delete_vm_disk(resource_group, disk)
        delete_nic(resource_group, nic)
        delete_ip(resource_group, ip)
        append_file('omsfiles/{0}-extnwatcher.log'.format(distname), log_open)
        append_file('omsfiles/{0}-omsagent.log'.format(distname), log_open)
        log_open.close()

def create_report(messages):
    """Compile the final HTML report."""

    install_oms_msg, verify_oms_msg, instantupgrade_verify_msg, instantupgrade_status_msg, autoupgrade_verify_msg, autoupgrade_status_msg, remove_oms_msg, reinstall_oms_msg, long_verify_msg, long_status_msg = messages
    result_log_file = open("finalresult.log", "a+")

    # summary table
    diststh = ""
    resultsth = ""
    for vmname in vmnames:
        distname = vmname.split('-')[0]
        diststh += """
                <th>{0}</th>""".format(distname)
        resultsth += """
                <th><a href='#{0}'>{0} results</a></th>""".format(distname)
    
    if instantupgrade_verify_msg and instantupgrade_status_msg:
        instantupgrade_summary = """
        <tr>
          <td>Instant Upgrade Verify Data</td>
          {0}
        </tr>
        <tr>
          <td>Instant Upgrade Status</td>
          {1}
        </tr>
        """.format(instantupgrade_verify_msg, instantupgrade_status_msg)
    else:
        instantupgrade_summary = ""

    if autoupgrade_verify_msg and autoupgrade_status_msg:
        autoupgrade_summary = """
        <tr>
          <td>AutoUpgrade Verify Data</td>
          {0}
        </tr>
        <tr>
          <td>AutoUpgrade Status</td>
          {1}
        </tr>
        """.format(autoupgrade_verify_msg, autoupgrade_status_msg)
    else:
        autoupgrade_summary = ""
    
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
    {4}
    <tr>
        <td>Remove OMSAgent</td>
        {5}
    </tr>
    <tr>
        <td>Reinstall OMSAgent</td>
        {6}
    </tr>
    {7}
    <tr>
        <td>Result Link</td>
        {8}
    <tr>
    </table>
    """.format(diststh, install_oms_msg, verify_oms_msg, instantupgrade_summary, autoupgrade_summary, remove_oms_msg, reinstall_oms_msg, long_running_summary, resultsth)
    result_html_file.write(statustable)

    # Create final html & log file
    for vmname in vmnames:
        distname = vmname.split('-')[0]
        append_file(distname + "result.log", result_log_file)
        append_file(distname + "result.html", result_html_file)
    
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
    
    file_types = ['*result.*', 'omsfiles/*-extnwatcher.log', 'omsfiles/*-omsagent.log']
    for files in file_types:
        for f in glob.glob(files):
            shutil.move(os.path.join(f), os.path.join('results/'))

if __name__ == '__main__':
    main()
