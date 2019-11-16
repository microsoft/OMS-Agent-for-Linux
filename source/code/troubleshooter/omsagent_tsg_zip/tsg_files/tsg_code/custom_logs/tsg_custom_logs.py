from tsg_info                import tsginfo_lookup
from tsg_errors              import is_error, get_input, print_errors
from install.tsg_checkoms    import get_oms_version
from install.tsg_install     import check_installation
from connect.tsg_checkendpts import check_log_analytics_endpts
from connect.tsg_connect     import check_connection
from heartbeat.tsg_heartbeat import start_omsagent, check_omsagent_running, check_heartbeat
from .tsg_checkclconf        import check_customlog_conf

def check_custom_logs(prev_success=0):
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
        print_errors(111)
        print("Running the installation part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_installation(err_codes=False, prev_success=101)

    # check connection
    checked_la_endpts = check_log_analytics_endpts()
    if (checked_la_endpts != 0):
        print_errors(checked_la_endpts)
        print("Running the connection part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_connection(err_codes=False, prev_success=101)

    # check running
    checked_omsagent_running = check_omsagent_running(tsginfo_lookup('WORKSPACE_ID'))
    if (checked_omsagent_running != 0):
        print_errors(checked_omsagent_running)
        print("Running the general health part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_heartbeat(prev_success=101)

    # check customlog.conf
    print("Checking for custom log configuration files...")
    checked_clconf = check_customlog_conf()
    if (is_error(checked_clconf)):
        return print_errors(checked_clconf)
    else:
        success = print_errors(checked_clconf)

    return success

    
        