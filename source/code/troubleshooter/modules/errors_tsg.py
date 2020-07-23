from error_codes          import *
from errors               import error_info, get_input, is_error
from connect.check_endpts import check_internet_connect

# urlopen() in different packages in Python 2 vs 3
try:
    from urllib.request import urlopen
except ImportError:
    from urllib2 import urlopen

TSG_URL = "https://raw.github.com/microsoft/OMS-Agent-for-Linux/master/docs/Troubleshooting.md"

# TODO: grab these directly from https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/oms-linux#error-codes-and-their-meanings
extension_err_codes_dict = {
    '0'  : "No errors found",
    '9'  : "Enable called prematurely, try updating the Azure Linux Agent to the latest available version",
    '10' : "VM is already connected to a Log Analytics workspace",
    '11' : "Invalid config provided to the extension",
    '17' : "Log Analytics package installation failure",
    '19' : "OMI package installation failure",
    '20' : "SCX package installation failure",
    '51' : "This extension is not supported on the VM's operation system",
    '55' : "Cannot connect to the Azure Monitor service, or required packages missing, or dpkg package manager is locked"
}



# get error codes from Troubleshooting.md
def get_error_codes(err_type):
    # extension
    if (err_type == 'Extension'):
        return (extension_err_codes_dict, None)

    # shell bundle or onboarding
    err_codes = {0 : "No errors found"}
    section_name = "{0} Error Codes".format(err_type)
    try:
        ts_doc = urlopen(TSG_URL)
        section = None
        for line in ts_doc.readlines():
            line = line.decode('utf8').rstrip('\n')
            if (line == ''):
                continue
            if (line.startswith('##')):
                section = line[3:]
                continue
            if (section == section_name):
                parsed_line = list(map(lambda x : x.strip(' '), line.split('|')))[1:-1]
                if (parsed_line[0] in ['Error Code', '---']):
                    continue
                err_codes[parsed_line[0]] = parsed_line[1]
                continue
            if (section==section_name and line.startswith('#')):
                break
        return (err_codes, None)

    except Exception as e:
        checked_urlopen = check_urlopen_errs(e)

        # issue with connecting to Github specifically
        if (checked_urlopen == ERR_ENDPT):
            print("WARNING: can't connect to {0}: {1}\n Skipping this check...".format(TSG_URL, e))
            print("--------------------------------------------------------------------------------")
            return (None, 0)

        # issue with general internet connectivity / ssl package
        error_info.append((TSG_URL, e))
        return (None, checked_urlopen)



# check errors involving urlopen function
def check_urlopen_errs(err_msg):
    # error in connection, check connection
    checked_internet = check_internet_connect()
    if (is_error(checked_internet)):
        return checked_internet

    # ssl package not installed
    if (err_msg == "<urlopen error unknown url type: https>"):
        try:
            import ssl
        except ImportError:
            error_info.append(('ssl',))
            return ERR_PYTHON_PKG

    # connection in general fine, connecting to current page not
    return ERR_ENDPT



# ask user if they encountered error code
def ask_error_codes(err_type, err_types):
    # ask if user has error code
    answer = get_input("Do you have an {0} error code? (y/n)".format(err_type.lower()),\
                       (lambda x : x.lower() in ['y','yes','n','no']),\
                       "Please type either 'y'/'yes' or 'n'/'no' to proceed.")
    if (answer.lower() in ['y','yes']):
        # get dict of all error codes
        (err_codes, tsg_error) = get_error_codes(err_type)
        if (err_codes == None):
            return tsg_error

        # ask user for error code
        poss_ans = lambda x : x.isdigit() or (x in ['NOT_DEFINED', 'none'])
        err_code = get_input("Please input the error code", poss_ans,\
                             "Please enter an error code ({0})\nto get the error message, or "\
                                "type 'none' to continue with the troubleshooter.".format(err_types))
        # did user give integer, but not valid error code
        while (err_code.isdigit() and (not err_code in list(err_codes.keys()))):
            print("{0} is not a valid {1} error code.".format(err_code, err_type.lower()))
            err_code = get_input("Please input the error code", poss_ans,\
                                 "Please enter an error code ({0})\nto get the error message, or type "\
                                    "'none' to continue with the troubleshooter.".format(err_types))
        # print out error, ask to exit
        if (err_code != 'none'):
            print("\nError {0}: {1}\n".format(err_code, err_codes[err_code]))
            answer1 = get_input("Would you like to continue with the troubleshooter? (y/n)",\
                                (lambda x : x.lower() in ['y','yes','n','no']),
                                "Please type either 'y'/'yes' or 'n'/'no' to proceed.")
            if (answer1.lower() in ['n','no']):
                print("Exiting troubleshooter...")
                print("================================================================================")
                return USER_EXIT
    print("Continuing on with troubleshooter...")
    print("--------------------------------------------------------------------------------")
    return NO_ERROR



# make specific for installation versus onboarding
def ask_install_error_codes():
    print("--------------------------------------------------------------------------------")
    print("Installation error codes can be found for either shell bundle or extension\n"\
          "installation, and can help give a quick idea of what went wrong (separate \n"\
          "from the troubleshooter's tests).")
    do_install_tests = get_input("Do you have an installation code from either installing via shell bundle (b) or\n"\
                                    "via extension (e)? (Type 's' to skip)",\
                                 (lambda x : x.lower() in ['b','bundle','e','extension','s','skip']),\
                                 "Please enter 'bundle'/'b' for a shell bundle code, 'extension'/'e' for an\n"\
                                    "extension code, or 's'/'skip' to skip.")
    
    # shell bundle error code
    if (do_install_tests.lower() in ['b','bundle']):
        print("--------------------------------------------------------------------------------")
        print("Shell bundle error codes can be found by going through the command output in \n"\
              "the terminal after running the `omsagent-*.universal.x64.sh` script to find \n"\
              "a line that matches:\n"\
              "\n    Shell bundle exiting with code <err>\n")
        return ask_error_codes('Installation', "either an integer or 'NOT_DEFINED'")

    # extension error code
    elif (do_install_tests.lower() in ['e','extension']):
        print("--------------------------------------------------------------------------------")
        print("Data about the state of extension deployments can be retrieved from the Azure \n"\
              "portal, and by using the Azure CLI.")
        return ask_error_codes('Extension', "an integer")

    # requested to skip
    else:
        print("Continuing on with troubleshooter...")
        print("--------------------------------------------------------------------------------")



def ask_onboarding_error_codes():
    print("--------------------------------------------------------------------------------")
    print("Onboarding error codes can help give a quick idea of what went wrong (separate \n"\
          "from the troubleshooter's tests).")
    print("Onboarding error codes can be found by running the command:\n"\
          "\n    echo $?\n\n"\
          "directly after running the `/opt/microsoft/omsagent/bin/omsadmin.sh` tool.")
    return ask_error_codes('Onboarding', "an integer")