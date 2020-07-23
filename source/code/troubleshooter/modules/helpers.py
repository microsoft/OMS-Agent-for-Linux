import errno
import os
import platform
import ssl
import subprocess

from error_codes import *
from errors      import error_info, print_errors

# urlopen() in different packages in Python 2 vs 3
try:
    from urllib.request import urlopen
except ImportError:
    from urllib2 import urlopen

CONF_PATH = "/etc/opt/microsoft/omsagent/conf/omsadmin.conf"

general_info = dict()

def add_geninfo(key, value):
    general_info[key] = value
    return

def geninfo_lookup(key):
    try:
        val = general_info[key]
    except KeyError:
        updated_geninfo = update_geninfo_all()
        if (updated_geninfo != NO_ERROR):
            print_errors(updated_geninfo)
            return None
        val = general_info[key]
    if (val == ''):
        return None
    return val



# All functions that update general_info

# CPU Bits
def get_os_bits():
    cpu_info = subprocess.check_output(['lscpu'], universal_newlines=True)
    cpu_opmodes = (cpu_info.split('\n'))[1]
    cpu_bits = cpu_opmodes[-6:]
    general_info['CPU_BITS'] = cpu_bits
    return cpu_bits

dist_to_id = {'redhat' : 'rhel',
              'centos' : 'centos',
              'red hat' : 'rhel',
              'oracle' : 'oracle',
              'debian' : 'debian',
              'ubuntu' : 'ubuntu',
              'suse' : 'sles',
              'sles' : 'sles',
              'amzn' : 'amzn'}



# OS Info
def get_os_version():
    # get vm info
    try:
        (vm_dist, vm_ver, vm_id) = platform.linux_distribution()
    except AttributeError:
        (vm_dist, vm_ver, vm_id) = platform.dist()
    # if above didn't work, get vm info through os_release
    if (not vm_dist and not vm_ver):
        try:
            with open('/etc/os-release', 'r') as os_file:
                for line in os_file:
                    parsed_line = line.split('=')
                    if (parsed_line[0] == 'ID'):
                        vm_dist = (parsed_line[1].split('-'))[0]
                        vm_dist = (vm_dist.replace('\"','')).replace('\n','')
                    elif (parsed_line[0] == 'VERSION_ID'):
                        vm_ver = (parsed_line[1].split('.'))[0]
                        vm_ver = (vm_ver.replace('\"','')).replace('\n','')
        except:
            return None

    # update general_info
    general_info['OS_ID'] = vm_dist
    general_info['OS_VERSION_ID'] = vm_ver
    for dist in dist_to_id.keys():
        if (vm_dist.lower().startswith(dist)):
            general_info['OS_READABLE_ID'] = dist_to_id[dist]
    return (vm_dist, vm_ver)



# Package Manager
def update_pkg_manager():
    # try dpkg
    try:
        is_dpkg = subprocess.check_output(['which', 'dpkg'], \
                    universal_newlines=True, stderr=subprocess.STDOUT)
        if (is_dpkg != ''):
            general_info['PKG_MANAGER'] = 'dpkg'
            return NO_ERROR
    except subprocess.CalledProcessError:
        pass
    # try rpm
    try:
        is_rpm = subprocess.check_output(['which', 'rpm'], \
                    universal_newlines=True, stderr=subprocess.STDOUT)
        if (is_rpm != ''):
            general_info['PKG_MANAGER'] = 'rpm'
            return NO_ERROR
    except subprocess.CalledProcessError:
        pass
    # neither
    return ERR_PKG_MANAGER



# Package Info
def get_dpkg_pkg_version(pkg):
    try:
        dpkg_info = subprocess.check_output(['dpkg', '-s', pkg], universal_newlines=True,\
                                            stderr=subprocess.STDOUT)
        dpkg_lines = dpkg_info.split('\n')
        for line in dpkg_lines:
            if (line.startswith('Package: ') and not line.endswith(pkg)):
                # wrong package
                return None
            if (line.startswith('Status: ') and not line.endswith('installed')):
                # not properly installed
                return None
            if (line.startswith('Version: ')):
                version = (line.split())[-1]
                general_info['{0}_VERSION'.format(pkg.upper())] = version
                return version
        return None
    except subprocess.CalledProcessError:
        return None

def get_rpm_pkg_version(pkg):
    try:
        rpm_info = subprocess.check_output(['rpm', '-qi', pkg], universal_newlines=True,\
                                            stderr=subprocess.STDOUT)
        if ("package {0} is not installed".format(pkg) in rpm_info):
            # didn't find package
            return None
        rpm_lines = rpm_info.split('\n')
        for line in rpm_lines:
            # parse line
            # note: parsing is weird bc rpm puts various information into two columns
            parsed_line = line.split()
            if (parsed_line[0] == 'Name'):
                # ['Name', ':', name, 'Relocations', ':', relocations]
                name = parsed_line[2]
                if (name != pkg):
                    # wrong package
                    return None
            if (parsed_line[0] == 'Version'):
                # ['Version', ':', version, 'Vendor', ':', 'MSFT']
                version = parsed_line[2]
                general_info['{0}_VERSION'.format(pkg.upper())] = version
                return version
        return None
    except subprocess.CalledProcessError:
        return None


# Recent OMS Version
def get_curr_oms_version(OMSAGENT_URL):
    try:
        doc_file = urlopen(OMSAGENT_URL)
        for line in doc_file.readlines():
            line = line.decode('utf8')
            if line.startswith("omsagent | "):
                parsed_line = line.split(' | ') # [package, version, description]
                general_info['UPDATED_OMS_VERSION'] = parsed_line[1]
                return (parsed_line[1], NO_ERROR)
        return (None, None)

    except Exception as e:
        return (None, e)



# omsadmin.conf
def update_omsadmin():
    try:
        with open(CONF_PATH, 'r') as conf_file:
            for line in conf_file:
                parsed_line = (line.rstrip('\n')).split('=')
                general_info[parsed_line[0]] = '='.join(parsed_line[1:])
        return NO_ERROR
    except IOError as e:
        if (e.errno == errno.EACCES):
            error_info.append((CONF_PATH,))
            return ERR_SUDO_PERMS
        elif (e.errno == errno.ENOENT):
            error_info.append(('file', CONF_PATH))
            return ERR_FILE_MISSING
        else:
            raise



# service controller
def check_service_controller():
    # check systemd
    try:
        is_systemctl = subprocess.check_output(['which', 'systemctl'], \
                        universal_newlines=True, stderr=subprocess.STDOUT)
        general_info['SERVICE_CONTROLLER'] = 'systemctl'
        return NO_ERROR
    except subprocess.CalledProcessError:
        # systemd not on VM, try other service controllers
        INVOKE_RC_PATH = "/usr/sbin/invoke-rc.d"
        SERVICE_PATH = "/sbin/service"
        SYSTEMCTL_PATH = "/bin/systemctl"
        def is_exec(fp):
            return (os.path.isfile(fp) and os.access(fp, os.X_OK))
        # try invoke-rc.d
        if (is_exec(INVOKE_RC_PATH)):
            general_info['SERVICE_CONTROLLER'] = INVOKE_RC_PATH
            return NO_ERROR
        # try service
        elif (is_exec(SERVICE_PATH)):
            general_info['SERVICE_CONTROLLER'] = SERVICE_PATH
            return NO_ERROR
        # try systemctl (via direct path)
        elif (is_exec(SYSTEMCTL_PATH)):
            general_info['SERVICE_CONTROLLER'] = SYSTEMCTL_PATH
            return NO_ERROR
        # none worked
        else:
            return ERR_SERVICE_CONTROLLER



# update all
def update_geninfo_all():
    # cpu_bits
    bits = get_os_bits()
    if (bits not in ['32-bit', '64-bit']):
        return ERR_BITS
    # os info
    os = get_os_version()
    if (os == None):
        return ERR_FINDING_OS
    # package manager
    pkg = update_pkg_manager()
    if (pkg != NO_ERROR):
        return pkg
    # dpkg packages
    if (general_info['PKG_MANAGER'] == 'dpkg'):
        if (get_dpkg_pkg_version('omsconfig') == None):
            return ERR_OMSCONFIG
        if (get_dpkg_pkg_version('omi') == None):
            return ERR_OMI
        if (get_dpkg_pkg_version('scx') == None):
            return ERR_SCX
        if (get_dpkg_pkg_version('omsagent') == None):
            return ERR_OMS_INSTALL
    # rpm packages
    elif (general_info['PKG_MANAGER'] == 'rpm'):
        if (get_rpm_pkg_version('omsconfig') == None):
            return ERR_OMSCONFIG
        if (get_rpm_pkg_version('omi') == None):
            return ERR_OMI
        if (get_rpm_pkg_version('scx') == None):
            return ERR_SCX
        if (get_rpm_pkg_version('omsagent') == None):
            return ERR_OMS_INSTALL
    # omsadmin info
    omsadmin = update_omsadmin()
    if (omsadmin != NO_ERROR):
        return omsadmin
    # service controller
    service_controller = check_service_controller()
    if (service_controller != NO_ERROR):
        return service_controller
    # all successful
    return NO_ERROR