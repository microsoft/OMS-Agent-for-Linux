#!/usr/bin/python

'''
   OMS Health Check Script for Update Management Linux VM's

   Authors, Reviewers & Contributors :
                 Tommy Nguyen Azure Automation SE
                 Atchut Barli Azure Automation Sr. SE
                 Shipra Malik Ohri Azure Automation Sr. SE
                 Shujun Liu Azure Automation Sr. SE
                 Adrian Doyle Sr. Esc. Eng.
                 Brian McDermott Sr. Esc. Eng.

   Date        : 2018-07-06
   Version     : 1.0
   
'''

import sys
import os
import os.path
import socket
import datetime

from os import walk

def main(output_path=None):

    output = []

    output.append(check_network() + "\n")
    output.append(check_oms_agent_installed() + "\n")
    output.append(check_oms_agent_running() + "\n")
    output.append(check_oms_admin() + "\n")
    output.append(check_hybrid_worker_running() + "\n")
    output.append(get_machine_info() + "\n")

    output.append("\n")

    if output_path is not None:
        try: 
            os.makedirs(output_path)
        except OSError:
            if not os.path.isdir(output_path):
                raise
        f = open(output_path + "/healthcheck-" + str(datetime.datetime.utcnow().isoformat()) + ".log", "w")
        f.write("".join(output))

    print "".join(output)

def check_network():
    output = []
    output.append("Network check: \n\n")

    endpoints = ["bing.com", "google.com"]
    
    agent_regions = ["jpe", "eus2", "cc", "scus", "uks", "sea"]
    agent_endpoint = "-agentservice-prod-arm-1.trafficmanager.net"

    jrds_regions = ["wcus", "ncus"]
    jrds_endpoint = "-jobruntimedata-prod-arm-1.trafficmanager.net"

    ods_endpoints = ["*.ods.opinsights.azure.com", "*.oms.opinsights.azure.com", "ods.systemcenteradvisor.com"]

    ff_endpoints = ["usge-jobruntimedata-prod-1.usgovtrafficmanager.net", "usge-agentservice-prod-1.usgovtrafficmanager.net", 
                    "*.ods.opinsights.azure.us", "*.oms.opinsights.azure.us" ]

    workspace = get_workspace()

    for endpoint in endpoints:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        response = sock.connect_ex((endpoint, 443))

        if response == 0:
            output.append(endpoint + ": success\n")
        else:
            output.append(endpoint + ": failure\n")

    output.append("\n")
        
    for region in agent_regions:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            response = sock.connect_ex((str(region + agent_endpoint), 443))

            if response == 0:
                output.append(region + agent_endpoint + ": success\n")
            else:
                output.append(region + agent_endpoint + ": failure\n")

        except Exception as ex:
            output.append(region + agent_endpoint + ": failure\n")
            output.append(str(ex) + "\n")

    output.append("\n")

    for region in jrds_regions:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            response = sock.connect_ex((str(region + jrds_endpoint), 443))

            if response == 0:
                output.append(region + jrds_endpoint + ": success\n")
            else:
                output.append(region + jrds_endpoint + ": failure\n")

        except Exception as ex:
            output.append(region + jrds_endpoint + ": failure\n")
            output.append(str(ex) + "\n")

    output.append("\n")
    
    for endpoint in ods_endpoints:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        new_endpoint = None
        
        if "*" in endpoint and workspace is not None:
            new_endpoint = endpoint.replace("*", workspace)
        elif "*" not in endpoint:
            new_endpoint = endpoint

        if new_endpoint is not None:
            try:
                response = sock.connect_ex((new_endpoint, 443))

                if response == 0:
                    output.append(new_endpoint + ": success\n")
                else:
                    output.append(new_endpoint + ": failure\n")

            except Exception as ex:
                output.append(new_endpoint + ": failure (this is normal if region is in Fairfax) \n")
                output.append(str(ex) + "\n")
    
    output.append("\n")

    for endpoint in ff_endpoints:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        new_endpoint = None
        
        if "*" in endpoint and workspace is not None:
            new_endpoint = endpoint.replace("*", workspace)
        elif "*" not in endpoint:
            new_endpoint = endpoint

        if new_endpoint is not None:
            try:
                response = sock.connect_ex((new_endpoint, 443))

                if response == 0:
                    output.append(new_endpoint + ": success\n")
                else:
                    output.append(new_endpoint + ": failure\n")

            except Exception as ex:
                output.append(new_endpoint + ": failure (this is normal if the region is not Fairfax).\n")
                output.append(str(ex) + "\n")
        
    return "".join(output)

def check_oms_agent_installed():
    oms_agent_dir = "/var/opt/microsoft/omsagent"
    oms_agent_log = "/var/opt/microsoft/omsagent/log/omsagent.log"

    agent_status = ["Oms Agent: \n"]

    if os.path.isdir(oms_agent_dir):
        # Check for omsagent.log
        if os.path.isfile(oms_agent_log):
            agent_status.append("omsagent.log exists. Oms Agent looks to be installed. \n")
        else:
            agent_status.append("File /var/opt/microsoft/omsagent/log/omsagent.log does not exist. Is the omsagent installed? \n")    
        
        # Check for multihoming of workspaces
        directories = []
        potential_workspaces = []

        for (dirpath, dirnames, filenames) in walk(oms_agent_dir):
            directories.extend(dirnames)
            break # Get the top level of directories

        for directory in directories:
            if len(directory) >= 32:
                potential_workspaces.append(directory)

        if len(potential_workspaces) > 1:
            agent_status.append("OMS Agent may be multihomed. Potential workspaces: " + str(potential_workspaces) + "\n")

    else:
        agent_status.append("Directory /var/opt/microsoft/omsagent/ does not exist. Is the omsagent installed? \n")

    return "".join(agent_status)

def check_hybrid_worker_running():
    output = os.popen("ps aux | grep worker").read()

    hybrid_worker_status = []

    if "python /opt/microsoft/omsconfig/modules/nxOMSAutomationWorker/DSCResources/MSFT_nxOMSAutomationWorkerResource/automationworker/worker/hybridworker.py" in output:
        hybrid_worker_status.append("Hybrid worker seems to be running. \n\n")
    else:
        hybrid_worker_status.append("Hybrid worker does not seem to be running. \n\n")

    hybrid_worker_status.append("Hybrid worker output: \n" + str(output))

    return ''.join(hybrid_worker_status)

def check_oms_agent_running():
    output = os.popen("ps aux | grep omsagent").read()

    hybrid_worker_status = []

    if "omsagent.log" or "omsagent.conf" in output:
        hybrid_worker_status.append("OMS Agent seems to be running. \n\n")
    else:
        hybrid_worker_status.append("OMS Agent does not seem to be running. \n\n")

    hybrid_worker_status.append("OMS Agent output: \n" + str(output))

    return ''.join(hybrid_worker_status)

def check_oms_admin():
    oms_admin_path = "/etc/opt/microsoft/omsagent/conf/omsadmin.conf"

    output = []

    output.append("OMS Admin Conf: \n\n")

    if os.path.isfile(oms_admin_path):
        oms_admin_file = open(oms_admin_path, 'r')

        for line in oms_admin_file:
            output.append(line)
        return "".join(output)
    else:
        return "omsadmin.conf file not found"

def get_workspace():
    oms_admin_path = "/etc/opt/microsoft/omsagent/conf/omsadmin.conf"

    if os.path.isfile(oms_admin_path):
        oms_admin_file = open(oms_admin_path, 'r')

        for line in oms_admin_file:
            if "WORKSPACE" in line:
                workspace = line.split("=")[1]
                return str(workspace).strip()
    
    return None

def get_machine_info():
    output = []

    output.append("\nMachine Information: \n")
    hostname_output = os.popen("hostnamectl").read()
    output.append(hostname_output + "\n")

    return "".join(output)

if __name__ == '__main__':
    if len(sys.argv) > 1:
        main(sys.argv[1])
    else:
        main()