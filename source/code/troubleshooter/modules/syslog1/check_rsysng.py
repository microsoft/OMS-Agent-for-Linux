import subprocess

from error_codes import *
from errors      import error_info

def check_systemctl():
    try:
        is_systemctl = subprocess.check_output(['which', 'systemctl'], \
                        universal_newlines=True, stderr=subprocess.STDOUT)
        if (is_systemctl != 0):
            return NO_ERROR
    except subprocess.CalledProcessError:
        return ERR_SYSTEMCTL

def check_sys_service(service):
    try:
        rsys_status = subprocess.check_output(['systemctl','status',service], \
                        universal_newlines=True, stderr=subprocess.STDOUT)
        rsys_lines = rsys_status.split('\n')
        for line in rsys_lines:
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

def check_services():
    check_rsyslog = check_sys_service('rsyslog')
    # rsyslog successful
    if (check_rsyslog == NO_ERROR):
        return NO_ERROR

    check_syslogng = check_sys_service('syslogng')
    # syslogng successful
    if (check_syslogng == NO_ERROR):
        return NO_ERROR

    # neither successful
    if (check_rsyslog==ERR_SYSLOG and check_syslogng==ERR_SYSLOG):
        return ERR_SYSLOG
    else:
        return ERR_SERVICE_STATUS
