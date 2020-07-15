from error_codes          import *
from errors               import is_error, get_input, print_errors
from helpers              import geninfo_lookup
from install.check_oms    import get_oms_version
from install.install      import check_installation
from connect.check_endpts import check_log_analytics_endpts
from connect.connect      import check_connection
from heartbeat.heartbeat  import start_omsagent, check_omsagent_running, check_heartbeat
from .check_clconf        import check_customlog_conf

def check_custom_logs(interactive, prev_success=NO_ERROR):
    if (interactive):
        print(" To check if you are using custom logs, please go to https://ms.portal.azure.com\n"\
            " and navigate to your workspace. Once there, please navigate to the 'Advanced\n"\
            " settings' blade, and then go to 'Data' > 'Custom Logs'. There you should be\n"\
            " to see any custom logs you may have.\n")
        using_cl = get_input("Are you currently using custom logs? (y/n)",\
                            (lambda x : x in ['y','yes','n','no']),\
                            "Please type either 'y'/'yes' or 'n'/'no' to proceed.")
        # not using custom logs
        if (using_cl in ['n','no']):
            print("Continuing on with the rest of the troubleshooter...")
            print("================================================================================")
            return prev_success
        # using custom logs
        else:
            print("Continuing on with troubleshooter...")
            print("--------------------------------------------------------------------------------")

    print("CHECKING FOR CUSTOM LOG ISSUES...")

    success = prev_success

    # check if installed / connected / running correctly
    print("Checking if omsagent installed and running...")
    # check installation
    if (get_oms_version() == None):
        print_errors(ERR_OMS_INSTALL)
        print("Running the installation part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_installation(interactive, err_codes=False, prev_success=ERR_FOUND)

    # check connection
    checked_la_endpts = check_log_analytics_endpts()
    if (checked_la_endpts != NO_ERROR):
        print_errors(checked_la_endpts)
        print("Running the connection part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_connection(interactive, err_codes=False, prev_success=ERR_FOUND)

    # check running
    checked_omsagent_running = check_omsagent_running(geninfo_lookup('WORKSPACE_ID'))
    if (checked_omsagent_running != NO_ERROR):
        print_errors(checked_omsagent_running)
        print("Running the general health part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_heartbeat(interactive, prev_success=ERR_FOUND)

    # check customlog.conf
    print("Checking for custom log configuration files...")
    checked_clconf = check_customlog_conf(interactive)
    if (is_error(checked_clconf)):
        return print_errors(checked_clconf)
    else:
        success = print_errors(checked_clconf)

    return success

    
        