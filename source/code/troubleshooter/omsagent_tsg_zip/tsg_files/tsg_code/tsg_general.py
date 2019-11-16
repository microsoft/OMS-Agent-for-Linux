import os

from tsg_errors                    import is_error, get_input, print_errors, err_summary
from install.tsg_install           import check_installation
from connect.tsg_connect           import check_connection
from heartbeat.tsg_heartbeat       import check_heartbeat
from high_cpu_mem.tsg_high_cpu_mem import check_high_cpu_memory
from syslog1.tsg_syslog            import check_syslog
from custom_logs.tsg_custom_logs   import check_custom_logs

# check to make sure the user is running as root
def check_sudo():
    if (os.geteuid() != 0):
        print("The troubleshooter is not currently being run as root. In order to "\
              "have accurate results, we ask that you run this troubleshooter as root.\n"\
              "The OMS Agent Troubleshooter needs to be run as root for the following reasons:")
        print("  - getting workspace ID and other relevant information to debugging")
        print("  - checking files in folders with strict permissions")
        print("  - checking certifications exist / are correct")
        # TODO: add more reasons as troubleshooter changes
        print("NOTE: it will not add, modify, or delete any files without express permission.")
        print("Please try running the troubleshooter again with 'sudo'. Thank you!")
        return False
    else:
        return True

# TODO: remove function when everything is implemented
def unimplemented():
    print("This part of the troubleshooter is unimplemented yet, please come back later for more updates!")
    return 0



# run through all troubleshooting scenarios
def check_all():
    all_success = 0
    # 1: Install
    checked_install = check_installation()
    if (is_error(checked_install)):
        return checked_install
    else:
        all_success = checked_install
    
    print("================================================================================")
    # 2: Connection
    checked_connection = check_connection()
    if (is_error(checked_connection)):
        return checked_connection
    else:
        all_success = checked_connection

    print("================================================================================")
    # 3: Heartbeat
    checked_hb = check_heartbeat()
    if (is_error(checked_hb)):
        return checked_hb
    else:
        all_success = checked_hb

    print("================================================================================")
    checked_highcpumem = check_high_cpu_memory()
    if (is_error(checked_highcpumem)):
        return checked_highcpumem
    else:
        all_success = checked_highcpumem

    print("================================================================================")
    checked_syslog = check_syslog()
    if (is_error(checked_syslog)):
        return checked_syslog
    else:
        all_success = checked_syslog

    print("================================================================================")
    checked_cl = check_custom_logs()
    if (is_error(checked_cl)):
        return checked_cl
    else:
        all_success = checked_cl

    return all_success




def run_tsg():
    # check if running as sudo
    if (not check_sudo()):
        return

    print("Welcome to the OMS Agent for Linux Troubleshooter! What is your issue?\n"\
        "================================================================================\n"\
        "1: Installation failure\n"\
        "2: Agent doesn't start, can't connect to Log Analytic Services\n"\
        "3: Agent is unhealthy, heartbeat data is missing\n"\
        "4: Agent has high CPU / memory usage\n"\
        "5: Syslog isn't working\n"\
        "6: Custom logs aren't working\n"\
        "A: Run through all troubleshooting scenarios in order\n"\
        "Q: Quit troubleshooter\n"\
        "================================================================================")
    switcher = {
        '1': check_installation,
        '2': check_connection,
        '3': check_heartbeat,
        '4': check_high_cpu_memory,
        '5': check_syslog,
        '6': check_custom_logs,
        'A': check_all
    }
    issue = get_input("Please select an option",\
                      (lambda x : x in ['1','2','3','4','5','6','q','quit','a','all']),\
                      "Please enter an integer corresponding with your issue (1-6) to\n"\
                        "continue (or 'A' to run through all scenarios), or 'Q' to quit.")
    if (issue.lower() in ['q','quit']):
        print("Exiting the troubleshooter...")
        return
    section = switcher.get(issue.upper(), lambda: "Invalid input")
    print("================================================================================")
    success = section()

    print("================================================================================")
    print("================================================================================")
    # print out all errors/warnings
    if (len(err_summary) > 0):
        print("ALL ERRORS/WARNINGS ENCOUNTERED:")
        for err in err_summary:
            print("  {0}".format(err))
        print("--------------------------------------------------------------------------------")
        
    # no errors found
    if (success == 0):
        print("No errors were found.")
    # user requested to exit
    elif (success == 1):
        return
    # error found
    else:
        print("Please review the errors found above.")
    # give information to user about next steps
    print("If you still have an issue, please follow the link below in order to download\n"\
        "the OMS Linux Agent Log Collector tool:\n"\
        "\n    https://github.com/microsoft/OMS-Agent-for-Linux/blob/master/tools/LogCollector/"\
                    "OMS_Linux_Agent_Log_Collector.md\n\n"\
        "And run the Log Collector in order to grab logs pertinent to debugging.\n"\
        "In addition, please include the following information:\n"\
        "  - Azure Subscription ID where the Log Analytics Workspace is located\n"\
        "  - Workspace ID the agent has been onboarded to\n"\
        "  - Workspace Name\n"\
        "  - Region Workspace is located\n"\
        "  - Pricing Tier assigned to the Workspace\n"\
        "(The above points can all be found in Azure Support Center.)\n"\
        "  - Linux Distribution on the VM\n"\
        "  - Log Analytics Agent Version")
    return
    

run_tsg()