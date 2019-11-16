import os
import subprocess

from tsg_info        import update_pkg_manager
from tsg_errors      import tsg_error_info, is_error, ask_install_error_codes, print_errors
from .tsg_checkos    import check_os
from .tsg_checkoms   import check_oms
from .tsg_checkfiles import check_filesystem
from .tsg_checkpkgs  import check_packages



# check space in MB for each main directory
def check_space():
    success = 0
    dirnames = ["/etc", "/opt", "/var"]
    for dirname in dirnames:
        space = os.statvfs(dirname)
        free_space = space.f_bavail * space.f_frsize / 1024 / 1024
        if (free_space < 500):
            tsg_error_info.append((dirname, free_space))
            success = 106
    return success



# check certificate
def check_cert():
    crt_path = "/etc/opt/microsoft/omsagent/certs/oms.crt"
    try:
        crt_info = subprocess.check_output(['openssl','x509','-in',crt_path,'-text','-noout'],\
                        universal_newlines=True, stderr=subprocess.STDOUT)
        if (crt_info.startswith("Certificate:\n")):
            return 0
        tsg_error_info.append((crt_path,))
        return 116
    # error with openssl
    except subprocess.CalledProcessError as e:
        try:
            err = e.output.split('\n')[1].split(':')[5]
            # openssl permissions error
            if (err == "Permission denied"):
                tsg_error_info.append((crt_path,))
                return 100
            # openssl file existence error
            elif (err == "No such file or directory"):
                tsg_error_info.append(("file", crt_path))
                return 114
            # openssl some other error
            else:
                tsg_error_info.append((crt_path, err))
                return 125
        # catch-all in case of fluke error
        except:
            tsg_error_info.append((crt_path, e.output))
            return 125
    # general error
    except:
        tsg_error_info.append((crt_path,))
        return 116



# check RSA private key
def check_key():
    key_path = "/etc/opt/microsoft/omsagent/certs/oms.key"
    key_info = subprocess.check_output(['openssl','rsa','-in',key_path,'-check'],\
                    universal_newlines=True, stderr=subprocess.STDOUT)
    # check if successful
    if ("RSA key ok\n" in key_info):
        return 0

    try:
        err = e.output.split('\n')[1].split(':')[5]
        # openssl permissions error
        if (err == "Permission denied"):
            tsg_error_info.append((key_path,))
            return 100
        # openssl file existence error
        elif (err == "No such file or directory"):
            tsg_error_info.append(("file", key_path))
            return 114
        # openssl some other error
        else:
            tsg_error_info.append((key_path, err))
            return 125
    # cert error
    except:
        tsg_error_info.append((key_path,))
        return 117




# check all packages are installed
def check_installation(err_codes=True, prev_success=0):
    print("CHECKING INSTALLATION...")
    # keep track of if all tests have been successful
    success = prev_success
    
    if (err_codes):
        if (ask_install_error_codes() == 1):
            return 1

    # check OS
    print("Checking if running a supported OS version...")
    checked_os = check_os()
    if (is_error(checked_os)):
        return print_errors(checked_os)
    else:
        success = print_errors(checked_os)
    
    # check space available
    print("Checking if enough disk space is available...")
    checked_space = check_space()
    if (is_error(checked_space)):
        return print_errors(checked_space)
    else:
        success = print_errors(checked_space)

    # check package manager
    print("Checking if machine has a supported package manager...")
    checked_pkg_manager = update_pkg_manager()
    if (is_error(checked_pkg_manager)):
        return print_errors(checked_pkg_manager)
    else:
        success = print_errors(checked_pkg_manager)
    
    # check packages are installed
    print("Checking if packages installed correctly...")
    checked_packages = check_packages()
    if (is_error(checked_packages)):
        return print_errors(checked_packages)
    else:
        success = print_errors(checked_packages)

    # check OMS version
    print("Checking if running a supported version of OMS...")
    checked_oms = check_oms()
    if (is_error(checked_oms)):
        return print_errors(checked_oms)
    else:
        success = print_errors(checked_oms)

    # check all files
    print("Checking if all files installed correctly (may take some time)...")
    checked_files = check_filesystem()
    if (is_error(checked_files)):
        return print_errors(checked_files)
    else:
        success = print_errors(checked_files)

    # check certs
    print("Checking certificate and RSA key are correct...")
    # check cert
    checked_cert = check_cert()
    if (checked_cert != 0):
        success = print_errors(checked_cert)
    # check key
    checked_key = check_key()
    if (checked_key != 0):
        success = print_errors(checked_key)
    # return if at least one is false
    if (is_error(checked_cert) or is_error(checked_key)):
        return 101
    
    return success

    