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

    if os.geteuid() != 0:
        print "Please run this script in sudo"
        exit()

    output.append(get_machine_info() + "\n")
    output.append(check_oms_admin() + "\n")
    output.append(check_oms_agent_installed() + "\n")
    output.append(check_oms_agent_running() + "\n")
    output.append(check_hybrid_worker_installed() + "\n")
    output.append(check_hybrid_worker_running() + "\n")
    output.append(check_network() + "\n")

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

def check_endpoints(workspace, endpoints, success_message, failure_message):
    output = []

    for endpoint in endpoints:
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
                    output.append(new_endpoint + ": " + success_message + "\n")
                else:
                    output.append(new_endpoint + ": " + failure_message + "\n")

            except Exception as ex:
                output.append(new_endpoint + ": " + failure_message + "\n")
                output.append(str(ex) + "\n")

    return output

def check_network():
    output = []
    output.append("Network check: \n\n")

    endpoints = ["bing.com", "google.com"]
    agent_endpoints = []
    jrds_endpoints = []

    agent_endpoint = get_agent_endpoint()
    jrds_endpoint = get_jrds_endpoint()

    if agent_endpoint is not None:
        agent_endpoints.append(agent_endpoint)
    
    if jrds_endpoint is not None:
        jrds_endpoints.append(jrds_endpoint)

    ods_endpoints = ["*.ods.opinsights.azure.com", "*.oms.opinsights.azure.com", "ods.systemcenteradvisor.com"]

    ff_endpoints = ["usge-jobruntimedata-prod-1.usgovtrafficmanager.net", "usge-agentservice-prod-1.usgovtrafficmanager.net", 
                    "*.ods.opinsights.azure.us", "*.oms.opinsights.azure.us" ]

    workspace = get_workspace()

    output.extend(check_endpoints(workspace, endpoints, "success", "failure"))
    output.append("\n")
    output.extend(check_endpoints(workspace, agent_endpoints, "success", "failure"))
    output.append("\n")
    output.extend(check_endpoints(workspace, jrds_endpoints, "success", "failure"))
    output.append("\n")

    if check_ff() is True:
        output.extend(check_endpoints(workspace, ff_endpoints, "success", "failure"))
    else:
        output.extend(check_endpoints(workspace, ods_endpoints, "success", "failure"))

    output.append("\n")

    return "".join(output)

def get_jrds_endpoint():
    workspace = get_workspace()

    if workspace is not None:
        worker_conf_path = "/var/opt/microsoft/omsagent/" + workspace + "/state/automationworker/worker.conf"
        
        line = find_line_in_path("jrds_base_uri", worker_conf_path)
        
        if line is not None:
            return line.split("=")[1].split("/")[2].strip()

    return None

def get_agent_endpoint():
    oms_admin_path = "/etc/opt/microsoft/omsagent/conf/omsadmin.conf"
    line = find_line_in_path("agentservice", oms_admin_path)

    if line is not None:
        return line.split("=")[1].split("/")[2].strip()

    return None

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
    return grep_for_process("worker", 
                            ["python /opt/microsoft/omsconfig/modules/nxOMSAutomationWorker/DSCResources/MSFT_nxOMSAutomationWorkerResource/automationworker/worker/hybridworker.py"], 
                            "Hybrid worker")

def check_hybrid_worker_installed():
    workspace = get_workspace()

    if workspace is not None:
        worker_conf_path = "/var/opt/microsoft/omsagent/" + workspace + "/state/automationworker/worker.conf"

        if os.path.isfile(worker_conf_path):
            return "worker.conf exists. Hybrid worker looks to be installed. \n"
        else:
            return "worker.conf does not exist. Is hybrid worker installed? \n"

def check_oms_agent_running():
    return grep_for_process("omsagent", ["omsagent.log", "omsagent.conf"], "OMS Agent")

def grep_for_process(process_name, search_criteria, output_name):
    grep_output = os.popen("ps aux | grep " + process_name).read()

    output = []

    if any(search_text in grep_output for search_text in search_criteria):
        output.append(output_name + " seems to be running. \n\n")
    else:
        output.append(output_name + " does not seem to be running. \n\n")
    
    output.append(output_name + " output: \n" + str(grep_output))

    return "".join(output)

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
    line = find_line_in_path("WORKSPACE", oms_admin_path)

    if line is not None:
        return line.split("=")[1].strip()

    return None

def get_machine_info():
    output = []

    output.append("\nMachine Information: \n")
    hostname_output = os.popen("hostnamectl").read()
    output.append(hostname_output + "\n")

    return "".join(output)

def check_ff():
    oms_admin_path = "/etc/opt/microsoft/omsagent/conf/omsadmin.conf"
    oms_endpoint = find_line_in_path("OMS_ENDPOINT", oms_admin_path).split("=")[1]

    if oms_endpoint is not None:
        return ".us" in oms_endpoint

def find_line_in_path(search_text, path):
    if os.path.isfile(path):
        current_file = open(path, 'r')

        for line in current_file:
            if search_text in line:
                return line
    
    return None

if __name__ == '__main__':
    if len(sys.argv) > 1:
        main(sys.argv[1])
    else:
        main()