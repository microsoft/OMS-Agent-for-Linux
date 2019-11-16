import os
import subprocess

from tsg_errors import tsg_error_info

clconf_path = "/etc/opt/microsoft/omsagent/conf/omsagent.d/customlog.conf"





def check_customlog(log_dict):
    log_path = log_dict[path]
    # check if path exists
    if (not os.path.isfile(log_path)):
        # try splitting on like './' or something to check both file paths
        # if that doesn't work:
        tsg_error_info.append(('file', log_path))
        return 114

    # check if pos file exists
    log_pos_file = log_dict[pos_file]
    if (not os.path.isfile(log_pos_file)):
        tsg_error_info.append(('file', log_pos_file))
        return 114

    # check pos file contents
    with open(log_pos_file, 'r') as lpf:
        parsed_lines = lpf.readlines().split()
        # mismatch in pos file filepath and custom log filepath
        if (parsed_lines[0] != log_path):
            tsg_error_info.append((log_pos_file, log_path, clconf_path))
            return 139
        #TODO: check size custom log
        pos_size = parsed_lines[1]

        # check unique number with custom log
        un_pos = parsed_lines[2]
        log_ls_info = subprocess.check_output(['ls','-li',log_path])
        un_log = (log_ls_info.split())[0]
        un_log_hex = hex(int(un_log)).lstrip('0x').rstrip('L')
        if (un_pos != un_log_hex):
            tsg_error_info.append((log_path, un_log_hex, log_pos_file, un_pos, \
                                    clconf_path))
            return 140

    return 0
        

    

def check_customlog_conf():
    # verify customlog.conf exists / not empty
    if (not os.path.isfile(clconf_path)):
        tsg_error_info.append(('file',clconf_path))
        return 114
    if (os.stat(clconf_path).st_size == 0):
        tsg_error_info.append((clconf_path,))
        return 118

    with open(clconf_path, 'r') as cl_file:
        cl_lines = cl_file.readlines()
        curr_log = dict()
        in_log = False
        for cl_line in cl_lines:
            # start of new custom log
            if ((not in_log) and (cl_line=="<source>")):
                in_log = True
                continue
            # end of custom log
            elif (in_log and (cl_line=="</source>")):
                in_log = False
                checked_customlog = check_customlog(curr_log.deepcopy())
                if (checked_customlog != 0):
                    return checked_customlog
                curr_log = dict()
                continue
            # inside custom log
            elif (in_log):
                parsed_line = cl_line.lstrip('  ').split(' ')
                curr_log[parsed_line[0]] = parsed_line[1]
                continue

    return 0
