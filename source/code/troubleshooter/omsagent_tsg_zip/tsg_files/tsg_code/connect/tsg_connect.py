import os
import subprocess

from tsg_errors           import tsg_error_info, ask_onboarding_error_codes, is_error, \
                                 print_errors
from install.tsg_install  import check_installation
from install.tsg_checkoms import get_oms_version
from .tsg_checkendpts     import check_internet_connect, check_agent_service_endpt, \
                                 check_log_analytics_endpts
from .tsg_checke2e        import check_e2e

omsadmin_path = "/opt/microsoft/omsagent/bin/omsadmin.sh"



# Verify omsadmin.conf exists / not empty
def check_omsadmin(): 
    # check if exists
    if (not os.path.isfile(omsadmin_path)):
        tsg_error_info.append(('file', omsadmin_path))
        return 114
    # check if not empty
    if (os.stat(omsadmin_path).st_size == 0):
        tsg_error_info.append((omsadmin_path,))
        # TODO: copy contents into it upon asking?
        return 118
    # all good
    return 0
        



def check_connection(err_codes=True, prev_success=0):
    print("CHECKING CONNECTION...")

    success = prev_success

    if (err_codes):
        if (ask_onboarding_error_codes() == 1):
            return 1

    # check if installed correctly
    print("Checking if installed correctly...")
    if (get_oms_version() == None):
        print_errors(111)
        print("Running the installation part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_installation(err_codes=False, prev_success=101)

    # check omsadmin.conf
    print("Checking if omsadmin.conf created correctly...")
    checked_omsadmin = check_omsadmin()
    if (is_error(checked_omsadmin)):
        print_errors(checked_omsadmin)
        print("Running the installation part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_installation(err_codes=False, prev_success=101)

    # check general internet connectivity
    print("Checking if machine is connected to the internet...")
    checked_internet_connect = check_internet_connect()
    if (is_error(checked_internet_connect)):
        return print_errors(checked_internet_connect)
    else:
        success = print_errors(checked_internet_connect)

    # check if agent service endpoint connected
    print("Checking if agent service endpoint is connected...")
    checked_as_endpt = check_agent_service_endpt()
    if (is_error(checked_as_endpt)):
        return print_errors(checked_as_endpt)
    else:
        success = print_errors(checked_as_endpt)

    # check if log analytics endpoints connected
    print("Checking if log analytics endpoints are connected...")
    checked_la_endpts = check_log_analytics_endpts()
    if (is_error(checked_la_endpts)):
        return print_errors(checked_la_endpts)
    else:
        success = print_errors(checked_la_endpts)

    # check if queries are successful
    print("Checking if queries are successful...")
    checked_e2e = check_e2e()
    if (is_error(checked_e2e)):
        return print_errors(checked_e2e)
    else:
        success = print_errors(checked_e2e)
        
    return success

    
