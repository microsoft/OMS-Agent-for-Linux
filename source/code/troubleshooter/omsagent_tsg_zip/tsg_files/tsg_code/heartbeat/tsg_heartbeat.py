import re
import subprocess

from tsg_info             import tsginfo_lookup
from tsg_errors           import tsg_error_info, is_error, print_errors
from install.tsg_checkoms import get_oms_version
from install.tsg_install  import check_installation
from connect.tsg_connect  import check_connection
from .tsg_multihoming     import check_multihoming
from .tsg_log_hb          import check_log_heartbeat

omsadmin_conf_path = "/etc/opt/microsoft/omsagent/conf/omsadmin.conf"
omsadmin_sh_path = "/opt/microsoft/omsagent/bin/omsadmin.sh"
sc_path = "/opt/microsoft/omsagent/bin/service_control"



def check_omsagent_running_sc():
    # check if OMS is running through service control
    is_running = subprocess.call([sc_path, 'is-running'])
    if (is_running == 1):
        return 0
    elif (is_running == 0):
        # don't have any extra info
        return 122
    else:
        return 200  # TODO: fix error code

def check_omsagent_running_omsadmin(workspace):
    output = subprocess.check_output(['sh', omsadmin_sh_path, '-l'], universal_newlines=True)
    output_regx = "Primary Workspace: (\S+)    Status: (\w+)\((\b+)\)\n"
    output_matches = re.match(output_regx, output)

    if (output_matches == None):
        err_regx = "-e error	(\b+)\n"
        err_matches = re.match(err_regx, output)
        if (err_matches == None):
            return 200  # TODO: fix err code here
        # matched to error
        err_info = err_matches.groups()[0]
        # check if permission error
        if (err_info == "This script must be run as root or as the omsagent user."):
            tsg_error_info.append((omsadmin_sh_path,))
            return 100
        # some other error
        tsg_error_info.append((omsadmin_sh_path, err_info))
        return 125

    # matched to output
    (output_wkspc, status, details) = output_matches.groups()

    # check correct workspace
    if (output_wkspc != workspace):
        tsg_error_info.append(output_wkspc, workspace)
        return 121

    # check status
    if (status=="Onboarded" and details=="OMS Agent Running"):
        # enabled, running
        return 0
    elif (status=="Warning" and details=="OMSAgent Registered, Not Running"):
        # enabled, stopped
        return 123
    elif (status=="Saved" and details=="OMSAgent Not Registered, Workspace Configuration Saved"):
        # disabled
        return 124
    else:
        # unknown status
        info_text = "OMS Agent has status {0} ({1})".format(status, details)
        tsg_error_info.append((info_text,))
        return 122

def check_omsagent_running_ps(workspace):
    # check if OMS is running through 'ps'
    processes = subprocess.check_output(['ps', '-ef'], universal_newlines=True).split('\n')
    for process in processes:
        # check if process is OMS
        if (not process.startswith('omsagent')):
            continue

        # [ UID, PID, PPID, C, STIME, TTY, TIME, CMD ]
        process = process.split()
        command = ' '.join(process[7:])

        # try to match command with omsagent command
        regx_cmd = "/opt/microsoft/omsagent/ruby/bin/ruby /opt/microsoft/omsagent/bin/omsagent "\
                   "-d /var/opt/microsoft/omsagent/(\S+)/run/omsagent.pid "\
                   "-o /var/opt/microsoft/omsagent/(\S+)/log/omsagent.log "\
                   "-c /etc/opt/microsoft/omsagent/(\S+)/conf/omsagent.conf "\
                   "--no-supervisor"
        matches = re.match(regx_cmd, command)
        if (matches == None):
            continue

        matches_tup = matches.groups()
        guid = matches_tup[0]
        if (matches_tup.count(guid) != len(matches_tup)):
            continue

        # check if OMS is running with a different workspace
        if (workspace != guid):
            tsg_error_info.append((guid, workspace))
            return 121

        # OMS currently running and delivering to the correct workspace
        return 0

    # none of the processes running are OMS
    return 122

def check_omsagent_running(workspace):
    # check through is-running
    checked_sc = check_omsagent_running_sc()
    if (checked_sc != 122):
        return checked_sc

    # check if is a process
    checked_ps = check_omsagent_running_ps(workspace)
    if (checked_ps != 122):
        return checked_ps
    
    # get more info
    return check_omsagent_running_omsadmin(workspace)
        



def start_omsagent(workspace, enabled=False):
    print("Agent curently not running. Attempting to start omsagent...")
    result = 0
    # enable the agent if necessary
    if (not enabled):
        result = subprocess.call([sc_path, 'enable'])
    # start the agent if enable was successful
    result = (subprocess.call([sc_path, 'start'])) if (result == 0) else (result)

    # check if successful
    if (result == 0):
        return check_omsagent_running(workspace)
    elif (result == 127):
        # script doesn't exist
        tsg_error_info.append(('executable shell script', sc_path))
        return 114



def check_heartbeat(prev_success=0):
    print("CHECKING HEARTBEAT / HEALTH...")

    success = prev_success

    # TODO: run `sh /opt/microsoft/omsagent/bin/omsadmin.sh -l` to check if onboarded and running

    # check if installed correctly
    print("Checking if installed correctly...")
    if (get_oms_version() == None):
        print_errors(111)
        print("Running the installation part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_installation(err_codes=False, prev_success=101)

    # get workspace ID
    workspace = tsginfo_lookup('WORKSPACE_ID')
    if (workspace == None):
        tsg_error_info.append(('Workspace ID', omsadmin_conf_path))
        print_errors(119)
        print("Running the connection part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_connection(err_codes=False, prev_success=101)
    
    # check if running multi-homing
    print("Checking if omsagent is trying to run multihoming...")
    checked_multihoming = check_multihoming(workspace)
    if (is_error(checked_multihoming)):
        return print_errors(checked_multihoming)
    else:
        success = print_errors(checked_multihoming)

    # check if other agents are sending heartbeats
    # TODO

    # check if omsagent is running
    print("Checking if omsagent is running...")
    checked_omsagent_running = check_omsagent_running(workspace)
    if (checked_omsagent_running == 122):
        # try starting omsagent
        # TODO: find better way of doing this, check to see if agent is stopped / grab results
        checked_omsagent_running = start_omsagent(workspace)
    if (is_error(checked_omsagent_running)):
        return print_errors(checked_omsagent_running)
    else:
        success = print_errors(checked_omsagent_running)

    # check if omsagent.log finds any heartbeat errors
    print("Checking for errors in omsagent.log...")
    checked_log_hb = check_log_heartbeat(workspace)
    if (is_error(checked_log_hb)):
        # connection issue
        if (checked_log_hb == 128):
            print_errors(checked_log_hb)
            print("Running the connection part of the troubleshooter in order to find the issue...")
            print("================================================================================")
            return check_connection(err_codes=False, prev_success=101)
        # other issue
        else:
            return print_errors(checked_log_hb)
    else:
        success = print_errors(checked_log_hb)
    
    return success

