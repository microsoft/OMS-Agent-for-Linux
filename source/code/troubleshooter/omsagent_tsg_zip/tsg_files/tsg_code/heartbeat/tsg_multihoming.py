# INSPIRED BY update_mgmt_health_check.py

import os

from tsg_errors import tsg_error_info

def check_multihoming(workspace):
    directories = []
    potential_workspaces = []

    for (dirpath, dirnames, filenames) in os.walk("/var/opt/microsoft/omsagent"):
        directories.extend(dirnames)
        break # Get the top level of directories

    for directory in directories:
        if len(directory) >= 32:
            potential_workspaces.append(directory)
    workspace_id_list = ', '.join(potential_workspaces)

    # 2+ potential workspaces
    if len(potential_workspaces) > 1:
        tsg_error_info.append((workspace_id_list))
        return 129

    # 0 potential workspaces
    if (len(potential_workspaces) == 0):
        missing_dir = "/var/opt/microsoft/omsagent/{0}".format(workspace)
        tsg_error_info.append(('Directory', missing_dir))
        return 114

    # 1 incorrect workspace
    if (potential_workspaces[0] != workspace):
        tsg_error_info.append(potential_workspaces[0], workspace)
        return 121

    # 1 correct workspace
    return 0
        