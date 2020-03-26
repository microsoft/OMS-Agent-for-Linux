import errno
import re
import subprocess

from tsg_errors import tsg_error_info

def get_omsagent_logs(log_path):
    log_tail_size = 50
    lts_mult = 1
    parsed_log_lines = []
    log_template = r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} (\+|-)\d{4} \[\w+\]: .*$"

    try:
        # open omsagent.log
        with open(log_path, 'r') as log_file:
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
            tsg_error_info.append((log_path,))
            return (None, 100)
        # file doesn't exist
        elif (e.errno == errno.ENOENT):
            tsg_error_info.append(("file", log_path))
            return (None, 114)
        # some other error
        else:
            tsg_error_info.append((log_path, e))
            return (None, 125)



# check log for heartbeats
def check_log_heartbeat(workspace):
    log_path = "/var/opt/microsoft/omsagent/{0}/log/omsagent.log".format(workspace)
    (parsed_log_lines, get_logs_errs) = get_omsagent_logs(log_path)
    if (parsed_log_lines == None):
        return get_logs_errs

    # filter out errors
    parsed_log_errs = list(filter(lambda x : (x[3]) == '[error]', parsed_log_lines))
    if (len(parsed_log_errs) > 0):
        log_err_lines = list(map(lambda x : x[-1], parsed_log_errs))
        log_errs = '\n  ' + ('\n  '.join(log_err_lines))
        tsg_error_info.append((log_path, log_errs))
        return 126

    # filter warnings
    parsed_log_warns = list(filter(lambda x : (x[3]) == '[warn]', parsed_log_lines))
    if (len(parsed_log_warns) > 0):
        hb_fail_logs = list(filter(lambda x : 'failed to flush the buffer' in x[4], parsed_log_warns))
        if (len(hb_fail_logs) > 0):
            return 128
        else:
            log_warn_lines = list(map(lambda x : x[-1], parsed_log_warns))
            log_warns = '\n  ' + ('\n  '.join(log_warn_lines))
            tsg_error_info.append((log_path, log_warns))
            return 127

    # logs show no errors or warnings
    return 0
