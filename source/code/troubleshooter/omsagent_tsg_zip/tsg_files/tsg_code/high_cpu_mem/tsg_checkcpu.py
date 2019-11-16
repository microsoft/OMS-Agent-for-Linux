import os
import subprocess

from tsg_errors import tsg_error_info
from tsg_info   import tsginfo_lookup

script_dir = "/opt/microsoft/omsagent/plugin/troubleshooter/tsg_tools"
script_file = os.path.join(script_dir, 'omiHighCPUDiagnosticsTSG.sh')
tsg_output_file = os.path.join(script_dir, 'tsg_omiagent_trace')
output_file = os.path.join(script_dir, 'omiagent_trace')    



def get_pkg_ver(pkg):
    version = None
    try:
        pkg_manager = tsginfo_lookup('PKG_MANAGER')

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
    with open(tsg_output_file, 'r') as f:
        lines = f.readlines()
        # no threads over 80% threshold
        if (lines[0] == "No threads with high CPU utilization.\n"):
            return 0
        # some threads over 80% threshold, check permissions
        else:
            all_root = True
            for line in lines:
                parsed_line = line.split()

                # OMS running OMI too hot
                if ((parsed_line[-1] == 'omiagent') and (parsed_line[1] == 'omsagent')):
                    nss_ver = get_pkg_ver('nss-pem')
                    if (nss_ver == None):
                        tsg_error_info.append(('nss-pem',))
                        return 152
                    # check nss-pem version
                    if (nss_ver == '1.0.3-5.el7'):
                        return 143
                    else:
                        return 144

            # OMI running itself too hot
            tsg_error_info.append((output_file,))
            # TODO: include profile #s, distro, oms/omi versions; in some file
            return 142




def check_omi_cpu():
    # Run script
    try:
        script_output = subprocess.check_output(['bash',script_file,'--runtime-in-min','1',\
                            '--cpu-threshold','80'], universal_newlines=True, stderr=subprocess.STDOUT)
        # ran into issue
        if (not script_output.startswith("Traces will be saved to this file: ")):
            tsg_error_info.append((script_output,))
            return 141
        # Parse output
        return check_output_file()

    except subprocess.CalledProcessError as e:
        tsg_error_info.append((e.output,))
        return 141


