from tsg_info                import tsginfo_lookup
from tsg_errors              import is_error, print_errors
from install.tsg_checkoms    import get_oms_version
from install.tsg_install     import check_installation
from connect.tsg_checkendpts import check_log_analytics_endpts
from connect.tsg_connect     import check_connection
from heartbeat.tsg_heartbeat import start_omsagent, check_omsagent_running, check_heartbeat
from .tsg_checkconf          import check_conf_files
from .tsg_checkrsysng        import check_services

def check_syslog(prev_success=0):
    print("CHECKING FOR SYSLOG ISSUES...")

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

    # check for syslog.conf and 95-omsagent.conf
    print("Checking for syslog configuration files...")
    checked_conf_files = check_conf_files()
    if (is_error(checked_conf_files)):
        if (checked_conf_files in [111,114]):
            print_errors(checked_conf_files)
            print("Running the installation part of the troubleshooter in order to find the issue...")
            print("================================================================================")
            return check_installation(err_codes=False, prev_success=101)
        else:
            return print_errors(checked_conf_files)
    else:
        success = print_errors(checked_conf_files)

    # check rsyslog / syslogng running
    print("Checking if machine has rsyslog or syslog-ng running...")
    checked_services = check_services()
    if (is_error(checked_services)):
        return print_errors(checked_services)
    else:
        success = print_errors(checked_services)

    return success
        