import subprocess

from tsg_info import tsginfo_lookup, get_dpkg_pkg_version, get_rpm_pkg_version

def get_package_version(pkg):
    pkg_mngr = tsginfo_lookup('PKG_MANAGER')

    # dpkg
    if (pkg_mngr == 'dpkg'):
        return get_dpkg_pkg_version(pkg)
    # rpm
    elif (pkg_mngr == 'rpm'):
        return get_rpm_pkg_version(pkg)
    else:
        return None



# get current OMSConfig (DSC) version running on machine
def get_omsconfig_version():
    pkg_version = get_package_version('omsconfig')
    if (pkg_version == None):
        # couldn't find OMSConfig
        return None
    return pkg_version



# get current OMI version running on machine
def get_omi_version():
    pkg_version = get_package_version('omi')
    if (pkg_version == None):
        # couldn't find OMI
        return None
    return pkg_version



# get current SCX version running on machine
def get_scx_version():
    pkg_version = get_package_version('scx')
    if (pkg_version == None):
        # couldn't find SCX
        return None
    return pkg_version



# check to make sure all necessary packages are installed
def check_packages():
    if (get_omsconfig_version() == None):
        return 108

    if (get_omi_version() == None):
        return 109

    if (get_scx_version() == None):
        return 110
    
    return 0