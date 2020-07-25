import os
import subprocess

from error_codes import *
from errors      import error_info, is_error
from helpers     import add_geninfo, geninfo_lookup

RSYSLOG_DIR = "/etc/rsyslog.d"
OLD_RSYSLOG_DEST = "/etc/rsyslog.conf"
RSYSLOG_DEST = os.path.join(RSYSLOG_DIR, "95-omsagent.conf")
SYSLOG_NG_DEST = "/etc/syslog-ng/syslog-ng.conf"



# check syslog with systemctl
def check_sys_systemctl(service, controller):
    try:
        sys_status = subprocess.check_output([controller, 'status', service], \
                        universal_newlines=True, stderr=subprocess.STDOUT)
        sys_lines = sys_status.split('\n')
        for line in sys_lines:
            line = line.strip()
            if line.startswith('Active: '):
                stripped_line = line.lstrip('Active: ')
                # exists and running correctly
                if stripped_line.startswith('active (running) since '):
                    return NO_ERROR
                # exists but not running correctly
                else:
                    error_info.append((service, stripped_line, controller))
                    return ERR_SERVICE_STATUS
    except subprocess.CalledProcessError as e:
        # service not on machine
        if (e.returncode == 4):
            return ERR_SYSLOG
        else:
            error_info.append((service, e.output, controller))
            return ERR_SERVICE_STATUS

# check syslog with invoke-rc.d
def check_sys_invoke_rc(service, controller):
    try:
        sys_status = subprocess.check_output([controller, service, 'status'], \
                        universal_newlines=True, stderr=subprocess.STDOUT)
        sys_line = sys_status.split('\n')[0]
        sys_info = sys_line.split()  # [service, status+',', 'process', PID]
        status = sys_info[1].rstrip(',')  # [goal+'/'+curr_state]
        if (status == 'start/running'):
            # exists and running correctly
            return NO_ERROR
        else:
            # exists but not running correctly
            error_info.append((service, status, controller))
            return ERR_SERVICE_STATUS
    except subprocess.CalledProcessError as e:
        # service not on machine
        if (e.returncode == 100):
            return ERR_SYSLOG
        else:
            error_info.append((service, e.output, controller))
            return ERR_SERVICE_STATUS

# check syslog with service
def check_sys_service(service, controller):
    try:
        sys_status = subprocess.check_output([controller, service, 'status'], \
                        universal_newlines=True, stderr=subprocess.STDOUT)
        sys_line = sys_status.split('\n')[0]
        sys_info = sys_line.split()  # [service, '(pid', pid+')', 'is', status+'...']
        status = sys_info[-1].rstrip('.')
        if (status == 'running'):
            # exists and running correctly
            return NO_ERROR
        else:
            # exists but not running correctly
            error_info.append((service, status, controller))
            return ERR_SERVICE_STATUS
    except subprocess.CalledProcessError as e:
        # permissions issue
        if (e.returncode == 4):
            return ERR_SUDO_PERMS
        # service not on machine
        elif ((e.returncode == 1) and ('unrecognized service' in e.output)):
            return ERR_SYSLOG
        else:
            error_info.append((service, e.output, controller))
            return ERR_SERVICE_STATUS



# check for syslog status through service controller
def check_sys(service):
    controller = geninfo_lookup('SERVICE_CONTROLLER')
    # systemctl
    if (controller.endswith('systemctl')):
        return check_sys_systemctl(service, controller)
    # invoke-rc.d
    elif (controller.endswith('invoke-rc.d')):
        return check_sys_invoke_rc(service, controller)
    # service
    elif (controller.endswith('service')):
        return check_sys_service(service, controller)
    # no service controller
    else:
        return ERR_SERVICE_CONTROLLER



# check for syslog through filepath existence
def check_sys_files():
    # old rsyslog
    if (os.path.isfile(OLD_RSYSLOG_DEST) and os.path.isdir(RSYSLOG_DIR)):
        add_geninfo('SYSLOG_DEST', OLD_RSYSLOG_DEST)
        return NO_ERROR
    # (new) rsyslog
    elif (os.path.isfile(OLD_RSYSLOG_DEST)):
        add_geninfo('SYSLOG_DEST', RSYSLOG_DEST)
        return NO_ERROR
    # syslog-ng
    elif (os.path.isfile(SYSLOG_NG_DEST)):
        add_geninfo('SYSLOG_DEST', SYSLOG_NG_DEST)
        return NO_ERROR
    # none found
    else:
        return ERR_SYSLOG



def check_services():
    checked_rsyslog = check_sys('rsyslog')
    # rsyslog successful
    if (checked_rsyslog == NO_ERROR):
        add_geninfo('SYSLOG_DEST', RSYSLOG_DEST)
        return NO_ERROR

    checked_syslog_ng = check_sys('syslog-ng')
    # syslog-ng successful
    if (checked_syslog_ng == NO_ERROR):
        add_geninfo('SYSLOG_DEST', SYSLOG_NG_DEST)
        return NO_ERROR

    # ran into error trying to get syslog
    if ((checked_rsyslog==ERR_SERVICE_STATUS) or (checked_syslog_ng==ERR_SERVICE_STATUS)):
        return ERR_SERVICE_STATUS

    # neither successful, try checking if files are there
    checked_files = check_sys_files()
    if (checked_files == NO_ERROR):
        return NO_ERROR
    
    # files aren't there
    return ERR_SYSLOG
