import os
import subprocess

from error_codes import *
from errors      import error_info
from helpers     import add_geninfo

RSYSLOG_DIR = "/etc/rsyslog.d"
OLD_RSYSLOG_DEST = "/etc/rsyslog.conf"
RSYSLOG_DEST = os.path.join(RSYSLOG_DIR, "95-omsagent.conf")
SYSLOG_NG_DEST = "/etc/syslog-ng/syslog-ng.conf"



def check_systemctl():
    try:
        is_systemctl = subprocess.check_output(['which', 'systemctl'], \
                        universal_newlines=True, stderr=subprocess.STDOUT)
        if (is_systemctl != 0):
            return NO_ERROR
    except subprocess.CalledProcessError:
        return ERR_SYSTEMCTL



# check for syslog through using systemctl
def check_sys_service(service):
    try:
        sys_status = subprocess.check_output(['systemctl','status',service], \
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
                    error_info.append((service, stripped_line))
                    return ERR_SERVICE_STATUS
    except subprocess.CalledProcessError as e:
        # service not on machine
        if (e.returncode == 4):
            return ERR_SYSLOG
        else:
            error_info.append((service, e.output))
            return ERR_SERVICE_STATUS



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
    checked_rsyslog = check_sys_service('rsyslog')
    # rsyslog successful
    if (checked_rsyslog == NO_ERROR):
        add_geninfo('SYSLOG_DEST', RSYSLOG_DEST)
        return NO_ERROR

    checked_syslog_ng = check_sys_service('syslog-ng')
    # syslogng successful
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
