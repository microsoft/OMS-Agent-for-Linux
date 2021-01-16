# INSPIRED BY update_mgmt_health_check.py

import subprocess

from error_codes import *
from errors      import error_info
from helpers     import geninfo_lookup

OMSADMIN_PATH = "/etc/opt/microsoft/omsagent/conf/omsadmin.conf"
SSL_CMD = "echo | openssl s_client -connect {0}:443 -brief"



# openssl connect to specific endpoint
def check_endpt_ssl(endpoint):
    try:
        ssl_output = subprocess.check_output(SSL_CMD.format(endpoint), shell=True,\
                     stderr=subprocess.STDOUT, universal_newlines=True)
        if (ssl_output.startswith("CONNECTION ESTABLISHED")):
            return True
        else:
            return False
    except Exception:
        return False



# check general internet connectivity
def check_internet_connect():
    if (check_endpt_ssl("docs.microsoft.com")):
        return NO_ERROR
    else:
        return ERR_INTERNET



# check agent service endpoint
def check_agent_service_endpt():
    dsc_endpt = geninfo_lookup('DSC_ENDPOINT')
    if (dsc_endpt == None):
        error_info.append(('DSC (agent service) endpoint', OMSADMIN_PATH))
        return ERR_INFO_MISSING
    agent_endpt = dsc_endpt.split('/')[2]

    if (check_endpt_ssl(agent_endpt)):
        return NO_ERROR
    else:
        error_info.append((agent_endpt, SSL_CMD.format(agent_endpt)))
        return ERR_ENDPT




# check log analytics endpoints
def check_log_analytics_endpts():
    success = NO_ERROR

    # get OMS endpoint to check if fairfax region
    oms_endpt = geninfo_lookup('OMS_ENDPOINT')
    if (oms_endpt == None):
        error_info.append(('OMS endpoint', OMSADMIN_PATH))
        return ERR_INFO_MISSING

    # get workspace ID
    workspace_id = geninfo_lookup('WORKSPACE_ID')
    if (workspace_id == None):
        error_info.append(('Workspace ID', OMSADMIN_PATH))
        return ERR_INFO_MISSING

    # get log analytics endpoints
    if ('.us' in oms_endpt):
        log_analytics_endpts = ["usge-jobruntimedata-prod-1.usgovtrafficmanager.net", \
            "usge-agentservice-prod-1.usgovtrafficmanager.net", "*.ods.opinsights.azure.us", \
            "*.oms.opinsights.azure.us"]
    else:
        log_analytics_endpts = ["*.ods.opinsights.azure.com", "*.oms.opinsights.azure.com", \
            "ods.systemcenteradvisor.com"]

    for endpt in log_analytics_endpts:
        # replace '*' with workspace ID
        if ('*' in endpt):
            endpt = endpt.replace('*', workspace_id)

        # ping endpoint
        if (not check_endpt_ssl(endpt)):
            error_info.append((endpt, SSL_CMD.format(endpt)))
            success = ERR_ENDPT

    return success