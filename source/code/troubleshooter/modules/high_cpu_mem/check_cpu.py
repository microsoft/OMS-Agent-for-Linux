import os
import subprocess

from error_codes import *
from errors      import error_info
from helpers     import geninfo_lookup

SCRIPT_DIR = "/opt/microsoft/omsagent/tst/modules/high_cpu_mem"
SCRIPT_FILE = os.path.join(SCRIPT_DIR, 'omiHighCPUDiagnosticsTST.sh')
TST_OUTPUT_FILE = os.path.join(SCRIPT_DIR, 'tst_omiagent_trace')
OUTPUT_FILE = os.path.join(SCRIPT_DIR, 'omiagent_trace')    



def get_pkg_ver(pkg):
    version = None
    try:
        pkg_manager = geninfo_lookup('PKG_MANAGER')

        # check using rpm
        if (pkg_manager == 'rpm'):
            pkg_info = subprocess.check_output(['rpm', '-qi', pkg], universal_newlines=True,\
                            stderr=subprocess.STDOUT)
            for line in pkg_info.split('\n'):
                # parse line
                parsed_line = line.split(': ')
                if (len(parsed_line > 2)):
                    parsed_line = [parsed_line[0]] + [parsed_line[1:].join(': ')]
                # check info
                if (parsed_line[0].startswith('Name') and parsed_line[1] != pkg):
                    # wrong package
                    return None
                if (parsed_line[0].startswith('Version')):
                    version = parsed_line[1]
                    continue
                if (parsed_line[0].startswith('Release')):
                    version = version + '-' + parsed_line[1]
                    break
        
        # check using dpkg
        elif (pkg_manager == 'dpkg'):
            pkg_info = subprocess.check_output(['dpkg', '-s', pkg], universal_newlines=True,\
                            stderr=subprocess.STDOUT)
            for line in pkg_info.split('\n'):
                # parse line
                parsed_line = line.split(': ')
                if (len(parsed_line > 2)):
                    parsed_line = [parsed_line[0]] + [parsed_line[1:].join(': ')]
                # check info
                if (parsed_line[0] == 'Package' and parsed_line[1] != pkg):
                    # wrong package
                    return None
                if (parsed_line[0] == 'Version'):
                    version = parsed_line[1]
                    break

        return version
    
    # no pkg
    except subprocess.CalledProcessError:
        return None
    





def check_output_file():
    with open(TST_OUTPUT_FILE, 'r') as f:
        lines = f.readlines()
        # no threads over 80% threshold
        if (lines[0] == "No threads with high CPU utilization.\n"):
            return NO_ERROR
        # some threads over 80% threshold, check permissions
        else:
            all_root = True
            for line in lines:
                parsed_line = line.split()

                # OMS running OMI too hot
                if ((parsed_line[-1] == 'omiagent') and (parsed_line[1] == 'omsagent')):
                    nss_ver = get_pkg_ver('nss-pem')
                    if (nss_ver == None):
                        error_info.append(('nss-pem',))
                        return ERR_PKG
                    # check nss-pem version
                    if (nss_ver == '1.0.3-5.el7'):
                        return ERR_OMICPU_NSSPEM
                    else:
                        return ERR_OMICPU_NSSPEM_LIKE

            # OMI running itself too hot
            error_info.append((OUTPUT_FILE,))
            # TODO: include profile #s, distro, oms/omi versions; in some file
            return ERR_OMICPU_HOT




def check_omi_cpu():
    # Run script
    try:
        script_output = subprocess.check_output(['bash',SCRIPT_FILE,'--runtime-in-min','1',\
                            '--cpu-threshold','80'], universal_newlines=True, stderr=subprocess.STDOUT)
        script_lines = script_output.split('\n')
        for script_line in script_lines:
            if (script_line.startswith("Traces will be saved to this file: ")):
                # started running successfully
                return check_output_file()
        # script didn't start running successfully
        error_info.append((script_output,))
        return ERR_OMICPU
    # process errored out
    except subprocess.CalledProcessError as e:
        error_info.append((e.output,))
        return ERR_OMICPU


