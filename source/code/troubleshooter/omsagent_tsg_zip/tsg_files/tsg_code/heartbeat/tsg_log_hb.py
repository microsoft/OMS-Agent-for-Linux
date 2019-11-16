import datetime
import re
import subprocess
import time

from tsg_errors import tsg_error_info

# check log for heartbeats
def check_log_heartbeat(workspace):
    # # wait 3 minutes to be able to check last 3 heartbeats
    # print("Waiting 3 minutes to collect last 3 heartbeats...")
    # time.sleep(180)

    # get tail of logs
    log_path = "/var/opt/microsoft/omsagent/{0}/log/omsagent.log".format(workspace)
    log_tail_size = 50
    lts_mult = 1
    parsed_log_lines = []
    log_template = r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} (\+|-)\d{4} \[\w+\]: .*$"
    try:
        while (parsed_log_lines == []):  # in case last 50 is all a conf file
            logs = subprocess.check_output(['tail','-n',str(log_tail_size*lts_mult),log_path],\
                    universal_newlines=True, stderr=subprocess.STDOUT)

            # parse logs
            log_lines = logs.split('\n')[:log_tail_size]
            for line in log_lines:
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

        # # filter logs to last 3 minutes
        # endtime_str = ' '.join(parsed_log_lines[-1][0:2])
        # endtime = datetime.strptime(endtime_str, '%y-%m-%d %H:%M:%S')
        # starttime = endtime - datetime.timedelta(minutes=3)
        # def in_last_3mins(log):
        #     logtime_str = ' '.join(log[0:2])
        #     logtime = datetime.strptime(logtime_str, '%y-%m-%d %H:%M:%S')
        #     return (logtime > starttime)
        # parsed_log_lines = list(filter(in_last_3mins, parsed_log_lines))

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

    # ran into an error with initial call
    except subprocess.CalledProcessError as e:
        # check for errors in tailing log file
        err_msg = "tail: cannot open '{0}' for reading: (\b+)\n".format(log_path)
        match_err = re.match(err_msg, e.output)

        if (e.returncode == 1 and match_err != None):
            err = (match_err.groups())[0]
            # tail permissions error
            if (err == "Permission denied"):
                tsg_error_info.append((log_path,))
                return 100
            # tail file existence error
            elif (err == "No such file or directory"):
                tsg_error_info.append(("file", log_path))
                return 114
            # tail some other error
            else:
                tsg_error_info.append((log_path, err))
                return 125
        # catch-all in case of fluke error
        else:
            tsg_error_info.append((log_path, e.output))
            return 125