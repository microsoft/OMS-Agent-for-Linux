import errno
import re
import subprocess

from error_codes import *
from errors      import error_info

def get_omsagent_logs(LOG_PATH):
    log_tail_size = 50
    lts_mult = 1
    parsed_log_lines = []
    log_template = r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} (\+|-)\d{4} \[\w+\]: .*$"

    try:
        # open omsagent.log
        with open(LOG_PATH, 'r') as log_file:
            log_lines = log_file.readlines()
            last_update_lines = log_lines
            # read from bottom up until run into end of omsagent.conf (printed when agent starts up)
            # then grab all logs after (for all logs since agent started)
            for i in range(len(log_lines)-1, -1, -1):
                if (log_lines[i] == "</ROOT>\n"):
                    last_update_lines = log_lines[i+1:]
                    break

            # parse logs
            for line in last_update_lines:
                line = line.rstrip('\n')
                # empty line
                if (line == ''):
                    continue
                # conf file text
                if (re.match(log_template, line) == None):
                    continue
                parsed_log = line.split(' ', 4)
                parsed_log[3] = parsed_log[3].rstrip(':')
                parsed_log.append(line)
                # [ date, time, zone, [logtype], log, unparsed log ]
                parsed_log_lines.append(parsed_log)
        
        return (parsed_log_lines, None)

    # ran into an error with opening file
    except IOError as e:
        # can't access due to permissions
        if (e.errno == errno.EACCES):
            error_info.append((LOG_PATH,))
            return (None, 100)
        # file doesn't exist
        elif (e.errno == errno.ENOENT):
            error_info.append(("file", LOG_PATH))
            return (None, ERR_FILE_MISSING)
        # some other error
        else:
            error_info.append((LOG_PATH, e))
            return (None, ERR_FILE_ACCESS)



# check log for heartbeats
def check_log_heartbeat(workspace):
    LOG_PATH = "/var/opt/microsoft/omsagent/{0}/log/omsagent.log".format(workspace)
    (parsed_log_lines, get_logs_errs) = get_omsagent_logs(LOG_PATH)
    if (parsed_log_lines == None):
        return get_logs_errs

    # filter out errors
    parsed_log_errs = list(filter(lambda x : (x[3]) == '[error]', parsed_log_lines))
    if (len(parsed_log_errs) > 0):
        log_err_lines = list(map(lambda x : x[-1], parsed_log_errs))
        log_errs = '\n  ' + ('\n  '.join(log_err_lines))
        error_info.append((LOG_PATH, log_errs))
        return ERR_LOG

    # filter warnings
    parsed_log_warns = list(filter(lambda x : (x[3]) == '[warn]', parsed_log_lines))
    if (len(parsed_log_warns) > 0):
        hb_fail_logs = list(filter(lambda x : 'failed to flush the buffer' in x[4], parsed_log_warns))
        if (len(hb_fail_logs) > 0):
            return ERR_HEARTBEAT
        else:
            log_warn_lines = list(map(lambda x : x[-1], parsed_log_warns))
            log_warns = '\n  ' + ('\n  '.join(log_warn_lines))
            error_info.append((LOG_PATH, log_warns))
            return WARN_LOG

    # logs show no errors or warnings
    return NO_ERROR
