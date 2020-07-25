import os
import re

from error_codes       import *
from errors            import error_info
from helpers           import geninfo_lookup
from install.check_oms import comp_versions_ge, get_oms_version

OMSADMIN_PATH = "/etc/opt/microsoft/omsagent/conf/omsadmin.conf"
SYSLOGCONF_PATH = "/etc/opt/microsoft/omsagent/conf/omsagent.d/syslog.conf"
SYSLOGDEST_PATH = ""

def parse_syslogconf():
    syslogconf_dict = dict()
    with open(SYSLOGCONF_PATH, 'r') as syslogconf_file:
        in_source = False
        for line in syslogconf_file:
            line = line.rstrip('\n')
            # only read inside <source>
            if (line == "<source>"):
                in_source = True
                continue
            # exiting <source>
            if (line == "</source>"):
                in_source = False
                continue
            if (in_source):
                parsed_line = line.strip().split()
                # making sure type is syslog
                if ((parsed_line[0] == 'type') and (parsed_line[1] != 'syslog')):
                    in_source = False
                    continue
                # add info to dictionary
                syslogconf_dict[parsed_line[0]] = parsed_line[1]
                continue
    # return dictionary with info
    return syslogconf_dict



def check_port(port, sys_bind, sys_pt):
    oms_version = get_oms_version()
    if (oms_version == None):
        return ERR_OMS_INSTALL

    # get number of '@'s in front of port
    corr_pt = None
    if (comp_versions_ge(oms_version, '1.12')):
        if (sys_pt == 'udp'):
            corr_pt = '@'
        elif (sys_pt == 'tcp'):
            corr_pt = '@@'
    elif (sys_pt in ['udp','tcp']):
        corr_pt = '@'
    # verify protocol type is valid
    if (corr_pt == None):
        error_info.append(("protocol type",SYSLOGCONF_PATH))
        return ERR_INFO_MISSING

    # syslog destination file is sending to right port
    corr_port = corr_pt + sys_bind
    if (port.startswith(corr_port)):
        return NO_ERROR
    # wrong number of '@'s
    pt_count = port.count('@')
    corr_pt_count = corr_pt.count('@')
    if (pt_count != corr_pt_count):
        pt = port[:pt_count]
        error_info.append((sys_pt, corr_pt, pt, SYSLOGDEST_PATH))
        return ERR_PT
    # wrong port
    curr_bind = (port[pt_count+1:]).split(':')[0]
    if (curr_bind != sys_bind):
        error_info.append((sys_bind, curr_bind, SYSLOGDEST_PATH))
        return ERR_PORT_MISMATCH
    # some other error?
    error_info.append((SYSLOGCONF_PATH, SYSLOGDEST_PATH))
    return ERR_PORT_SETUP

        
    

def check_syslogdest(sys_bind, sys_pt):
    # get workspace id
    workspace_id = geninfo_lookup('WORKSPACE_ID')
    if (workspace_id == None):
        error_info.append(('Workspace ID', OMSADMIN_PATH))
        return ERR_INFO_MISSING

    # set up regex lines
    comment_line = "# OMS Syslog collection for workspace (\S+)"
    spec_line = "(\w+).=alert;(\w+).=crit;(\w+).=debug;(\w+).=emerg;(\w+).=err;"\
                "(\w+).=info;(\w+).=notice;(\w+).=warning"

    # open file
    with open(SYSLOGDEST_PATH, 'r') as syslogdest_file:
        for line in syslogdest_file:
            line = line.rstrip('\n')
            # skip empty lines
            if (line == ''):
                continue
            
            # check if workspace for syslog collection lines up
            match_comment = re.match(comment_line, line)
            if (match_comment == None):
                continue
            syslog_wkspc = (match_comment.groups())[0]
            if (workspace_id != syslog_wkspc):
                error_info.append((syslog_wkspc, workspace_id, SYSLOGCONF_PATH))
                return ERR_SYSLOG_WKSPC
            else:
                continue

            # check if port is correct
            parsed_line = line.split()
            match_spec = re.match(spec_line, parsed_line[0])
            if (match_comment != None):
                checked_port = check_port(parsed_line[1], sys_port, sys_bind)
                if (checked_port != NO_ERROR):
                    return checked_port
                else:
                    continue
            else:
                continue
            
    # all ports set up correctly
    return NO_ERROR
            



def check_conf_files():
    # verify syslog.conf exists / not empty
    if (not os.path.isfile(SYSLOGCONF_PATH)):
        error_info.append(('file',SYSLOGCONF_PATH))
        return ERR_FILE_MISSING
    if (os.stat(SYSLOGCONF_PATH).st_size == 0):
        error_info.append((SYSLOGCONF_PATH,))
        return ERR_FILE_EMPTY

    # update syslog destination path with correct location
    syslog_dest = geninfo_lookup('SYSLOG_DEST')
    if (syslog_dest == None):
        return ERR_SYSLOG
    global SYSLOGDEST_PATH
    SYSLOGDEST_PATH = syslog_dest

    # verify syslog destination exists / not empty
    if (not os.path.isfile(SYSLOGDEST_PATH)):
        error_info.append(('file',SYSLOGDEST_PATH))
        return ERR_FILE_MISSING
    if (os.stat(SYSLOGDEST_PATH).st_size == 0):
        error_info.append((SYSLOGDEST_PATH,))
        return ERR_FILE_EMPTY

    # parse syslog.conf
    syslogconf_dict = parse_syslogconf()
    if (not syslogconf_dict):
        error_info.append(("syslog configuration info",SYSLOGCONF_PATH))
        return ERR_INFO_MISSING

    # get info for checking syslog destination file
    try:
        sys_bind = syslogconf_dict['bind']
        sys_pt = syslogconf_dict['protocol_type']
    except KeyError:
        error_info.append(("syslog configuration info",SYSLOGCONF_PATH))
        return ERR_INFO_MISSING

    # check with syslog destination file
    return check_syslogdest(sys_bind, sys_pt)