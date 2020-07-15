import errno
import os
import re
import subprocess

from error_codes import *
from errors      import error_info
from helpers     import geninfo_lookup

def hr2bytes(hr_size):
    if (hr_size.isdigit()):
        return int(hr_size)
    hr_digits = hr_size[:-1]
    hr_units = hr_size[-1]
    if (hr_digits.isdigit()):
        # kilobytes
        if (hr_units == 'k'):
            return int(hr_digits) * 1000
        # megabytes
        elif (hr_units == 'M'):
            return int(hr_digits) * 1000000
        # gigabytes
        elif (hr_units == 'G'):
            return int(hr_digits) * 1000000000
    # wrong formatting
    return None



def check_size_config(logrotate_configs, LR_CONFIG_PATH):
    for k in list(logrotate_configs.keys()):
        # grab size limit if exists
        size_config = next((x for x in logrotate_configs[k] if x.startswith('size ')), None)
        if (size_config == None):
            continue
        size_limit = hr2bytes(size_config.split()[1])
        if (size_limit == None):
            error_info.append((k, LR_CONFIG_PATH))
            return ERR_LOGROTATE_SIZE

        # get current size of file
        try:
            size_curr = os.path.getsize(k)
            if (size_curr > size_limit):
                error_info.append((k, size_curr, size_limit, LR_CONFIG_PATH))
                return ERR_LOGROTATE
            else:
                return NO_ERROR

        # couldn't get current size of file
        except os.error as e:
            if (e.errno == errno.EACCES):
                error_info.append((k,))
                return ERR_SUDO_PERMS
            elif (e.errno == errno.ENOENT):
                if ('missingok' in logrotate_configs[k]):
                    continue
                else:
                    error_info.append(('log file', k))
                    return ERR_FILE_MISSING
            else:
                error_info.append((k, e.strerror))
                return ERR_FILE_ACCESS




def check_log_rotation():
    workspace_id = geninfo_lookup('WORKSPACE_ID')
    LR_CONFIG_PATH = "/etc/logrotate.d/omsagent-{0}".format(workspace_id)

    # check logrotate config file exists
    if (not os.path.isfile(LR_CONFIG_PATH)):
        error_info.append(('logrotate config file', LR_CONFIG_PATH))
        return ERR_FILE_MISSING
    
    # go through logrotate config file
    logrotate_configs = dict()
    with open(LR_CONFIG_PATH, 'r') as f:
        lr_lines = f.readlines()
        in_file = None
        for lr_line in lr_lines:
            lr_line = lr_line.rstrip('\n')

            # start of log rotation config
            lr_start = re.match("^(\S+) \{$", lr_line)
            if (lr_start != None):
                in_file = lr_start.groups()[0]
                logrotate_configs[in_file] = set()
                continue
            # log rotation config info
            elif (in_file != None):
                logrotate_configs[in_file].add(lr_line.lstrip())
                continue
            # end of log rotation config
            elif (lr_line == '}'):
                in_file = None
                continue

    # check size rotation working
    checked_size_config = check_size_config(logrotate_configs, LR_CONFIG_PATH)
    if (checked_size_config != NO_ERROR):
        return checked_size_config

    return NO_ERROR