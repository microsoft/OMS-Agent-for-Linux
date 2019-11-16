import os
import re

from tsg_errors           import tsg_error_info
from tsg_info             import tsginfo_lookup
from install.tsg_checkoms import comp_versions_ge, get_oms_version

syslogconf_path = "/etc/opt/microsoft/omsagent/sysconf/omsagent.d/syslog.conf"
omsagent95_path = "/etc/rsyslog.d/95-omsagent.conf" # TODO: rsyslog vs syslogng

def parse_syslogconf():
    syslogconf_dict = dict()
    with open(syslogconf_path, 'r') as syslogconf_file:
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
        return 111

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
        tsg_error_info.append(("protocol type",syslogconf_path))
        return 119

    # 95-omsagent.conf is sending to right port
    corr_port = corr_pt + sys_bind
    if (port.startswith(corr_port)):
        return 0
    # wrong number of '@'s
    pt_count = port.count('@')
    corr_pt_count = corr_pt.count('@')
    if (pt_count != corr_pt_count):
        pt = port[:pt_count]
        tsg_error_info.append((sys_pt, corr_pt, pt, omsagent95_path))
        return 133
    # wrong port
    curr_bind = (port[pt_count+1:]).split(':')[0]
    if (curr_bind != sys_bind):
        tsg_error_info.append((sys_bind, curr_bind, omsagent95_path))
        return 134
    # some other error?
    tsg_error_info.append((syslogconf_path, omsagent95_path))
    return 135

        
    

def check_omsagent95(sys_bind, sys_pt):
    # grab workspace
    workspace = tsginfo_lookup('WORKSPACE_ID')
    if (workspace == None):
        tsg_error_info.append(('Workspace ID', omsadmin_path))
        return 119

    # set up regex lines
    comment_line = "# OMS Syslog collection for workspace (\S+)"
    spec_line = "(\w+).=alert;(\w+).=crit;(\w+).=debug;(\w+).=emerg;(\w+).=err;"\
                "(\w+).=info;(\w+).=notice;(\w+).=warning"

    # open file
    with open(omsagent95_path, 'r') as omsagent95_file:
        for line in omsagent95_file:
            line = line.rstrip('\n')
            # skip empty lines
            if (line == ''):
                continue
            
            # check if workspace for syslog collection lines up
            match_comment = re.match(comment_line, line)
            if (match_comment == None):
                continue
            syslog_wkspc = (match_comment.groups())[0]
            if (workspace != syslog_wkspc):
                tsg_error_info.append((syslog_wkspc,workspace,syslogconf_path))
                return 132
            else:
                continue

            # check if port is correct
            parsed_line = line.split()
            match_spec = re.match(spec_line, parsed_line[0])
            if (match_comment != None):
                checked_port = check_port(parsed_line[1], sys_port, sys_bind)
                if (checked_port != 0):
                    return checked_port
                else:
                    continue
            else:
                continue
            
    # all ports set up correctly
    return 0
            



def check_conf_files():
    # verify syslog.conf exists / not empty
    if (not os.path.isfile(syslogconf_path)):
        tsg_error_info.append(('file',syslogconf_path))
        return 114
    if (os.stat(syslogconf_path).st_size == 0):
        tsg_error_info.append((syslogconf_path,))
        return 118
    # verify 95-omsagent.conf exists / not empty
    if (not os.path.isfile(omsagent95_path)):
        tsg_error_info.append(('file',omsagent95_path))
        return 114
    if (os.stat(omsagent95_path).st_size == 0):
        tsg_error_info.append((omsagent95_path,))
        return 118

    # parse syslog.conf
    syslogconf_dict = parse_syslogconf()
    if (not syslogconf_dict):
        tsg_error_info.append(("syslog configuration info",syslogconf_path))
        return 119

    # get info for checking 95-omsagent.conf
    try:
        sys_bind = syslogconf_dict['bind']
        sys_pt = syslogconf_dict['protocol_type']
    except KeyError:
        tsg_error_info.append(("syslog configuration info",syslogconf_path))
        return 119

    # check with 95-omsagent.conf
    return check_omsagent95(sys_bind, sys_pt)