import subprocess

from tsg_errors import tsg_error_info

def check_systemctl():
    try:
        is_systemctl = subprocess.check_output(['which', 'dpkg'], \
                        universal_newlines=True, stderr=subprocess.STDOUT)
        if (is_systemctl != 0):
            return 0
    except subprocess.CalledProcessError:
        return 136

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
                    return 0
                # exists but not running correctly
                else:
                    tsg_error_info.append((service, stripped_line))
                    return 138
    except subprocess.CalledProcessError as e:
        # service not on machine
        if (e.returncode == 4):
            return 137
        else:
            tsg_error_info.append((service, e.output))
            return 138

def check_services():
    check_rsyslog = check_sys_service('rsyslog')
    # rsyslog successful
    if (check_rsyslog == 0):
        return 0

    check_syslogng = check_sys_service('syslogng')
    # syslogng successful
    if (check_syslogng == 0):
        return 0

    # neither successful
    if (check_rsyslog==137 and check_syslogng==137):
        return 137
    else:
        return 138
