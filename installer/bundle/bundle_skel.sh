#! /bin/sh

#
# Shell Bundle installer package for the OMS project
#

# This script is a skeleton bundle file for ULINUX only for project OMS.

PATH=/usr/bin:/usr/sbin:/bin:/sbin
umask 022

# Can't use something like 'readlink -e $0' because that doesn't work everywhere
# And HP doesn't define $PWD in a sudo environment, so we define our own
case $0 in
    /*|~*)
        SCRIPT_INDIRECT="`dirname $0`"
        ;;
    *)
        PWD="`pwd`"
        SCRIPT_INDIRECT="`dirname $PWD/$0`"
        ;;
esac

SCRIPT_DIR="`(cd \"$SCRIPT_INDIRECT\"; pwd -P)`"
SCRIPT="$SCRIPT_DIR/`basename $0`"
EXTRACT_DIR="`pwd -P`/omsbundle.$$"
ONBOARD_FILE=/etc/omsagent-onboard.conf
DPKG_CONF_QUALS="--force-confold --force-confdef"
OMISERV_CONF="/etc/opt/omi/conf/omiserver.conf"
OLD_OMISERV_CONF="/etc/opt/microsoft/scx/conf/omiserver.conf"
OMS_RUBY_DIR="/opt/microsoft/omsagent/ruby/bin"
OMS_CONSISTENCY_INVOKER="/etc/cron.d/OMSConsistencyInvoker"

# These symbols will get replaced during the bundle creation process.

TAR_FILE=<TAR_FILE>
OMS_PKG=<OMS_PKG>
DSC_PKG=<DSC_PKG>
SCX_INSTALLER=<SCX_INSTALLER>
INSTALL_TYPE=<INSTALL_TYPE>
SCRIPT_LEN=<SCRIPT_LEN>
SCRIPT_LEN_PLUS_ONE=<SCRIPT_LEN+1>

# Error codes and categories:

# User configuration/parameters:
INVALID_OPTION_PROVIDED=2
NO_OPTION_PROVIDED=3
INVALID_PACKAGE_TYPE=4
RUN_AS_ROOT=5
INVALID_PACKAGE_ARCH=6
# Accompanying packages issues:
SCX_INSTALL_FAILED=20
SCX_KITS_INSTALL_FAILED=21
BUNDLED_INSTALL_FAILED=22
USE_UPGRADE=23
# Internal errors:
INTERNAL_ERROR=30
# Package pre-requisites fail
UNSUPPORTED_OPENSSL=60
INSTALL_PYTHON_CTYPES=61
INSTALL_TAR=62
INSTALL_SED=63
INSTALL_CURL=64
INSTALL_GPG=65

usage()
{
    echo "usage: $1 [OPTIONS]"
    echo "Options:"
    echo "  --extract                  Extract contents and exit."
    echo "  --force                    Force upgrade (override version checks)."
    echo "  --install                  Install the package from the system."
    echo "  --purge                    Uninstall the package and remove all related data."
    echo "  --remove                   Uninstall the package from the system."
    echo "  --restart-deps             Reconfigure and restart dependent service(s)."
    echo "  --source-references        Show source code reference hashes."
    echo "  --upgrade                  Upgrade the package in the system."
    echo "  --enable-opsmgr            Enable port 1270 for usage with opsmgr."
    echo "  --version                  Version of this shell bundle."
    echo "  --version-check            Check versions already installed to see if upgradable."
    echo "  --debug                    use shell debug mode."
    echo
    echo "  -w id, --id id             Use workspace ID <id> for automatic onboarding."
    echo "  -s key, --shared key       Use <key> as the shared key for automatic onboarding."
    echo "  -d dmn, --domain dmn       Use <dmn> as the OMS domain for onboarding. Optional."
    echo "                             default: opinsights.azure.com"
    echo "                             ex: opinsights.azure.us (for FairFax)"
    echo "  -p conf, --proxy conf      Use <conf> as the proxy configuration."
    echo "                             ex: -p [protocol://][user:password@]proxyhost[:port]"
    echo "  -a id, --azure-resource id Use Azure Resource ID <id>."
    echo "  -m marker, --multi-homing-marker marker"
    echo "                             Onboard as a multi-homing(Non-Primary) workspace."
    echo
    echo "  -? | -h | --help           shows this usage text."
}

source_references()
{
    cat <<EOF
-- Source code references --
EOF
}

cleanup_and_exit()
{
    # $1: Exit status
    # $2: Non-blank (if we're not to delete bundles), otherwise empty

    if [ -z "$2" -a -d "$EXTRACT_DIR" ]; then
        cd $EXTRACT_DIR/..
        rm -rf $EXTRACT_DIR
    fi

    if [ -n "$1" ]; then
        echo "Shell bundle exiting with code $1"
        exit $1
    else
        exit 0
    fi
}

check_version_installable()
{
    # POSIX Semantic Version <= Test
    # Exit code 0 is true (i.e. installable).
    # Exit code non-zero means existing version is >= version to install.
    #
    # Parameter:
    #   Installed: "x.y.z.b" (like "4.2.2.135"), for major.minor.patch.build versions
    #   Available: "x.y.z.b" (like "4.2.2.135"), for major.minor.patch.build versions

    if [ $# -ne 2 ]; then
        echo "INTERNAL ERROR: Incorrect number of parameters passed to check_version_installable" >&2
        cleanup_and_exit $INTERNAL_ERROR
    fi

    # Current version installed
    local INS_MAJOR=`echo $1 | cut -d. -f1`
    local INS_MINOR=`echo $1 | cut -d. -f2`
    local INS_PATCH=`echo $1 | cut -d. -f3`
    local INS_BUILD=`echo $1 | cut -d. -f4`

    # Available version number
    local AVA_MAJOR=`echo $2 | cut -d. -f1`
    local AVA_MINOR=`echo $2 | cut -d. -f2`
    local AVA_PATCH=`echo $2 | cut -d. -f3`
    local AVA_BUILD=`echo $2 | cut -d. -f4`

    # Check bounds on MAJOR
    if [ $INS_MAJOR -lt $AVA_MAJOR ]; then
        return 0
    elif [ $INS_MAJOR -gt $AVA_MAJOR ]; then
        return 1
    fi

    # MAJOR matched, so check bounds on MINOR
    if [ $INS_MINOR -lt $AVA_MINOR ]; then
        return 0
    elif [ $INS_MINOR -gt $AVA_MINOR ]; then
        return 1
    fi

    # MINOR matched, so check bounds on PATCH
    if [ $INS_PATCH -lt $AVA_PATCH ]; then
        return 0
    elif [ $INS_PATCH -gt $AVA_PATCH ]; then
        return 1
    fi

    # PATCH matched, so check bounds on BUILD
    if [ $INS_BUILD -lt $AVA_BUILD ]; then
        return 0
    elif [ $INS_BUILD -gt $AVA_BUILD ]; then
        return 1
    fi

    # Version available is idential to installed version, so don't install
    return 1
}

getVersionNumber()
{
    # Parse a version number from a string.
    #
    # Parameter 1: string to parse version number string from
    #     (should contain something like mumble-4.2.2.135.universal.x86.tar)
    # Parameter 2: prefix to remove ("mumble-" in above example)

    if [ $# -ne 2 ]; then
        echo "INTERNAL ERROR: Incorrect number of parameters passed to getVersionNumber" >&2
        cleanup_and_exit $INTERNAL_ERROR
    fi

    echo $1 | sed -e "s/$2//" -e 's/\.universal\..*//' -e 's/\.x64.*//' -e 's/\.x86.*//' -e 's/-/./'
}

verifyNoInstallationOption()
{
    if [ -n "${installMode}" ]; then
        echo "$0: Conflicting qualifiers, exiting" >&2
        cleanup_and_exit $INVALID_OPTION_PROVIDED
    fi

    return;
}

verifyPrivileges()
{
    # Parameter: desired operation (for meaningful output)
    if [ -z "$1" ]; then
        echo "INTERNAL ERROR: verifyPrivileges missing required parameter (operation)" 1>& 2
        exit $INTERNAL_ERROR
    fi

    if [ `id -u` -ne 0 ]; then
        echo "Must have root privileges to be able to perform $1 operation" 1>& 2
        exit $RUN_AS_ROOT
    fi
}

ulinux_detect_openssl_version()
{
    TMPBINDIR=
    # the system OpenSSL version is 0.9.8.  Likewise with OPENSSL_SYSTEM_VERSION_100
    OPENSSL_SYSTEM_VERSION_FULL=`openssl version | awk '{print $2}'`
    OPENSSL_SYSTEM_VERSION_098=`echo $OPENSSL_SYSTEM_VERSION_FULL | grep -Eq '^0.9.8'; echo $?`
    OPENSSL_SYSTEM_VERSION_100=`echo $OPENSSL_SYSTEM_VERSION_FULL | grep -Eq '^1.0.'; echo $?`
    if [ $OPENSSL_SYSTEM_VERSION_098 = 0 ]; then
        TMPBINDIR=098
    elif [ $OPENSSL_SYSTEM_VERSION_100 = 0 ]; then
        TMPBINDIR=100
    else
        echo "Error: This system does not have a supported version of OpenSSL installed."
        echo "This system's OpenSSL version: $OPENSSL_SYSTEM_VERSION_FULL"
        echo "Supported versions: 0.9.8*, 1.0.*"
        cleanup_and_exit $UNSUPPORTED_OPENSSL
    fi
}

ulinux_detect_installer()
{
    INSTALLER=

    # If DPKG lives here, assume we use that. Otherwise we use RPM.
    check_if_program_in_path dpkg
    if [ $? -eq 0 ]; then
        INSTALLER=DPKG
    else
        INSTALLER=RPM
    fi
}

# $1 - The name of the package to check as to whether it's installed
check_if_pkg_is_installed()
{
    if [ "$INSTALLER" = "DPKG" ]; then
        dpkg -s $1 2> /dev/null | grep Status | grep " installed" 1> /dev/null
    else
        rpm -q $1 > /dev/null 2>&1
    fi

    return $?
}

check_if_program_in_path()
{
    # Parameter: name of program to check
    # Returns: 0 if program is in path, non-zero if not
    if [ $# -ne 1 ]; then
        echo "INTERNAL ERROR: Incorrect number of parameters passed to check_if_program_in_path" >&2
        cleanup_and_exit $INTERNAL_ERROR
    fi
    which $1 > /dev/null 2>&1
    return $?
}

check_if_program_exists_on_system()
{
    # Parameters: $1 - name of program to check
    # Returns: 0 if program is in system or installed as a package, 1 if not
    if [ $# -ne 1 ]; then
        echo "INTERNAL ERROR: Incorrect number of parameters passed to check_if_program_exists_on_system" >&2
        cleanup_and_exit $INTERNAL_ERROR
    fi
    local exists=1
    check_if_pkg_is_installed $1
    [ $? -eq 0 ] && exists=0
    check_if_program_in_path $1
    [ $? -eq 0 ] && exists=0
    return $exists
}

install_if_program_does_not_exist_on_system()
{
    # Parameters: $1 - name of program to check and possibly install
    # Returns: 0 if program is in system or installed as a package, 1 if not
    if [ $# -ne 1 ]; then
        echo "INTERNAL ERROR: Incorrect number of parameters passed to install_if_program_does_not_exist_on_system" >&2
        cleanup_and_exit $INTERNAL_ERROR
    fi

    check_if_program_exists_on_system $1
    if [ $? -eq 0 ]; then
        return 0
    fi

    echo "$1 was not found; attempting to install $1..."
    install_extra_package $1
    if [ $? -eq 0 ]; then
        return 0
    else
        # If package installation did not succeed, return the check status in case it's changed
        check_if_program_exists_on_system $1
        return $?
    fi
}

# $1 - The filename of the package to be installed
# $2 - The package name of the package to be installed (for future compatibility)
pkg_add_list()
{
    pkg_filename=$1
    pkg_name=$2

    ulinux_detect_openssl_version
    pkg_filename=$TMPBINDIR/$pkg_filename

    echo "----- Installing package: $2 ($1) -----"
    if [ "$INSTALLER" = "DPKG" ]; then
        add_list="${add_list} ${pkg_filename}.deb"
    else
        add_list="${add_list} ${pkg_filename}.rpm"
    fi
}

# $1 - The package name of the package to be uninstalled
pkg_rm()
{
    echo "----- Removing package: $1 -----"
    if [ "$INSTALLER" = "DPKG" ]; then
        if [ "$installMode" = "P" ]; then
            dpkg --purge ${1}
        else
            dpkg --remove ${1}
        fi
    else
        rpm --erase ${1}
    fi
    if [ $? -ne 0 ]; then
        echo "----- Ignore previous errors for package: $1 -----"
    fi
}

# $1 - The filename of the package to be installed
# $2 - The package name of the package to be installed
# $3 - Okay to upgrade the package? (Optional)
pkg_upd_list()
{
    pkg_filename=$1
    pkg_name=$2
    pkg_allowed=$3

    echo "----- Checking package: $2 ($1) -----"

    if [ -z "${forceFlag}" -a -n "$3" ]; then
        if [ $3 -ne 0 ]; then
            echo "Skipping package since existing version >= version available"
            return 0
        fi
    fi

    ulinux_detect_openssl_version
    pkg_filename=$TMPBINDIR/$pkg_filename

    if [ "$INSTALLER" = "DPKG" ]; then
        upd_list="${upd_list} ${pkg_filename}.deb"
    else
        upd_list="${upd_list} ${pkg_filename}.rpm"
    fi
}

get_arch()
{
    if [ $(getconf LONG_BIT) = 64 ]; then
        echo "x64"
    else
        echo "x86"
    fi
}

compare_arch()
{
    #check if the user is trying to install the correct bundle (x64 vs. x86)
    echo "Checking host architecture ..."
    HOST_ARCH=$(get_arch)
    
    case $OMS_PKG in
        *"$HOST_ARCH") 
            ;;
        *)         
            echo "Cannot install $OMS_PKG on ${HOST_ARCH} platform"
            cleanup_and_exit $INVALID_PACKAGE_ARCH
            ;;
    esac
}

compare_install_type()
{   
    # If the bundle has an INSTALL_TYPE, check if the bundle being installed 
    # matches the installer on the machine (rpm vs.dpkg)
    if [ ! -z "$INSTALL_TYPE" ]; then
        if [ $INSTALLER != $INSTALL_TYPE ]; then
           echo "This kit is intended for ${INSTALL_TYPE} systems and cannot install on ${INSTALLER} systems"
           cleanup_and_exit $INVALID_PACKAGE_TYPE
        fi
    fi
}

python_ctypes_installed()
{
    # Check for Python ctypes library (required for omsconfig)
    hasCtypes=1    
	
    # Attempt to run python with the single import command
    python -c "import ctypes" > /dev/null 2>&1
    [ $? -eq 0 ] && hasCtypes=0

    return $hasCtypes
}

getInstalledVersion()
{
    # Parameter: Package to check if installed
    # Returns: Printable string (version installed or "None")
    if check_if_pkg_is_installed $1; then
        if [ "$INSTALLER" = "DPKG" ]; then
            local version="`dpkg -s $1 2> /dev/null | grep 'Version: '`"
            getVersionNumber "$version" "Version: "
        else
            local version=`rpm -q $1 2> /dev/null`
            getVersionNumber $version ${1}-
        fi
    else
        echo "None"
    fi
}

shouldInstall_omsagent()
{
    local versionInstalled=`getInstalledVersion omsagent`
    [ "$versionInstalled" = "None" ] && return 0
    local versionAvailable=`getVersionNumber $OMS_PKG omsagent-`

    check_version_installable $versionInstalled $versionAvailable
}

shouldInstall_omsconfig()
{
    # Package omsconfig will never install without Python ctypes and curl ...
    if python_ctypes_installed; then
        if check_if_program_exists_on_system curl; then
            local versionInstalled=`getInstalledVersion omsconfig`
            [ "$versionInstalled" = "None" ] && return 0
            local versionAvailable=`getVersionNumber $DSC_PKG omsconfig-`

            check_version_installable $versionInstalled $versionAvailable
        else
            return 1
        fi
    else
        return 1
    fi
}

install_extra_package()
{
    # Parameter: package name to install
    # Returns: 0 on success, 1 on failure
    if [ $# -ne 1 ]; then
        echo "INTERNAL ERROR: Incorrect number of parameters passed to install_extra_package" >&2
        cleanup_and_exit $INTERNAL_ERROR
    fi

    local install_cmd=""

    which zypper > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        install_cmd="zypper --non-interactive install"
    fi
    which yum > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        install_cmd="yum install -y"
    fi
    which apt-get > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        install_cmd="apt-get install -y"
    fi

    if [ -z "$install_cmd" ]; then
        echo "No vendor found to install $1"
        return 1
    else
        $install_cmd $1
        return $?
    fi
}

#
# Main script follows
#

ulinux_detect_installer
set -e

while [ $# -ne 0 ]
do
    case "$1" in
        -d|--domain)
            topLevelDomain=$2
            shift 2
            ;;

        --extract-script)
            # hidden option, not part of usage
            # echo "  --extract-script FILE  extract the script to FILE."
            head -${SCRIPT_LEN} "${SCRIPT}" > "$2"
            shouldexit=true
            shift 2
            ;;

        --extract-binary)
            # hidden option, not part of usage
            # echo "  --extract-binary FILE  extract the binary to FILE."
            tail -n +${SCRIPT_LEN_PLUS_ONE} "${SCRIPT}" > "$2"
            shouldexit=true
            shift 2
            ;;

        --extract)
            verifyNoInstallationOption
            installMode=E
            shift 1
            ;;

        --force)
            forceFlag=true
            shift 1
            ;;

        --install)
            verifyNoInstallationOption
            verifyPrivileges "install"
            installMode=I
            shift 1
            ;;

        -p|--proxy)
            proxy=$2
            shift 2
            ;;

        --purge)
            verifyNoInstallationOption
            verifyPrivileges "purge"
            installMode=P
            shouldexit=true
            shift 1
            ;;

        --remove)
            verifyNoInstallationOption
            verifyPrivileges "remove"
            installMode=R
            shouldexit=true
            shift 1
            ;;

        --restart-deps)
            restartDependencies=--restart-deps
            shift 1
            ;;

        -s|--shared)
            onboardKey=$2
            shift 2
            ;;

        --source-references)
            source_references
            cleanup_and_exit 0
            ;;

        --version)
            echo "Version: `getVersionNumber $OMS_PKG omsagent-`"
            exit 0
            ;;

        --version-check)
            checkVersionAndCleanUp=true
            installMode=none
            shift 1
            ;;

        --upgrade)
            verifyNoInstallationOption
            verifyPrivileges "upgrade"
            installMode=U
            shift 1
            ;;

        -w|--id)
            onboardID=$2
            shift 2
            ;;

        --debug)
            echo "Starting shell debug mode." >&2
            echo "" >&2
            echo "SCRIPT_INDIRECT: $SCRIPT_INDIRECT" >&2
            echo "SCRIPT_DIR:      $SCRIPT_DIR" >&2
            echo "EXTRACT_DIR:     $EXTRACT_DIR" >&2
            echo "SCRIPT:          $SCRIPT" >&2
            echo >&2
            debugMode=true
            set -x
            shift 1
            ;;

        -a|--azure-resource)
            azureResourceID=$2
            shift 2
            ;;

        -m|--multi-homing-marker)
            multiHoming=$2
            shift 2
            ;;

        --enable-opsmgr)
            enableOMFlag=true
            shift 1
            ;;

        -\? | -h | --help)
            usage `basename $0` >&2
            cleanup_and_exit 0
            ;;

         *)
            echo "Unknown argument: '$1'" >&2
            echo "Use -h or --help for usage" >&2
            cleanup_and_exit $INVALID_OPTION_PROVIDED
            ;;
    esac
done

if [ -z "${installMode}" ]; then
    echo "$0: No options specified, specify --help for help" >&2
    cleanup_and_exit $NO_OPTION_PROVIDED
fi

ONBOARD_ERROR=0
[ -n "$topLevelDomain" ] && [ -z "$onboardID" -o -z "$onboardKey" ] && ONBOARD_ERROR=1
[ -z "$onboardID" -a -n "$onboardKey" ] && ONBOARD_ERROR=1
[ -n "$onboardID" -a -z "$onboardKey" ] && ONBOARD_ERROR=1

if [ "$ONBOARD_ERROR" -ne 0 ]; then
    echo "Must specify both workspace ID (--id) and key (--shared) to onboard" 1>& 2
    exit $INVALID_OPTION_PROVIDED
fi

if [ -n "$onboardID" -a -n "$onboardKey" ]; then
    verifyPrivileges "onboard"

    cat /dev/null > $ONBOARD_FILE
    chmod 600 $ONBOARD_FILE
    echo "WORKSPACE_ID=$onboardID" >> $ONBOARD_FILE
    echo "SHARED_KEY=$onboardKey" >> $ONBOARD_FILE

    if [ -n "$proxy" ]; then
        echo "PROXY=$proxy" >> $ONBOARD_FILE
    fi

    if [ -n "$topLevelDomain" ]; then
        echo "URL_TLD=$topLevelDomain" >> $ONBOARD_FILE
    fi

    if [ -n "$azureResourceID" ]; then
        echo "AZURE_RESOURCE_ID=$azureResourceID" >> $ONBOARD_FILE
    fi

    if [ -n "$multiHoming" ]; then
        echo "MULTI_HOMING_MARKER=$multiHoming" >> $ONBOARD_FILE
    fi

fi

#
# Note: From this point, we're in a temporary directory. This aids in cleanup
# from bundled packages in our package (we just remove the diretory when done).
#

mkdir -p $EXTRACT_DIR
cd $EXTRACT_DIR

# Do we need to remove the package?
set +e
if [ "$installMode" = "R" -o "$installMode" = "P" ]; then
    rm -f "$OMS_CONSISTENCY_INVOKER" > /dev/null 2>&1
    rm -f "$ONBOARD_FILE" > /dev/null 2>&1
    if [ -f /opt/microsoft/omsagent/bin/uninstall ]; then
        /opt/microsoft/omsagent/bin/uninstall $installMode
    else
        echo "---------- WARNING WARNING WARNING ----------"
        echo "Using new shell bundle to remove older kit."
        echo "Using fallback code to perform kit removal."
        echo "---------- WARNING WARNING WARNING ----------"
        echo

        # If bundled auoms is installed, then remove it
        check_if_pkg_is_installed auoms
        if [ $? -eq 0 ]; then
            pkg_rm auoms
        fi

        pkg_rm omsconfig
        pkg_rm omsagent

        # If MDSD is installed and we're just removing (not purging), leave SCX
        MDSD_INSTALLED=1
        check_if_program_exists_on_system azsec-mdsd
        if [ $? -eq 0 -o -d /var/lib/waagent/Microsoft.OSTCExtensions.LinuxDiagnostic-*/mdsd ]; then
            MDSD_INSTALLED=0
        fi

        if [ $MDSD_INSTALLED -ne 0 -o "$installMode" = "P" ]; then
            if [ -f /opt/microsoft/scx/bin/uninstall ]; then
                /opt/microsoft/scx/bin/uninstall $installMode
            else
                for i in /opt/microsoft/*-cimprov; do
                    PKG_NAME=`basename $i`
                    if [ "$PKG_NAME" != "*-cimprov" ]; then
                        echo "Removing ${PKG_NAME} ..."
                        pkg_rm ${PKG_NAME}
                    fi
                done

                # Now just simply pkg_rm scx and omi
                pkg_rm scx
                pkg_rm omi
            fi
        else
            echo "--- MDSD detected; not removing SCX or OMI packages ---"
        fi

        # If bundled auoms is installed, then remove it
        check_if_pkg_is_installed auoms
        if [ $? -eq 0 ]; then
            pkg_rm auoms
        fi

        if [ "$installMode" = "P" ]; then
            echo "Purging all files in cross-platform agent ..."

            #
            # Be careful to not remove files if dependent packages are still using them
            #

            check_if_pkg_is_installed omsconfig
            if [ $? -ne 0 ]; then
                rm -rf /etc/opt/microsoft/omsconfig /opt/microsoft/omsconfig /var/opt/microsoft/omsconfig
            fi

            check_if_pkg_is_installed omsagent
            if [ $? -ne 0 ]; then
                rm -rf /etc/opt/microsoft/omsagent /opt/microsoft/omsagent /var/opt/microsoft/omsagent
            fi

            check_if_pkg_is_installed scx
            if [ $? -ne 0 ]; then
                rm -rf /etc/opt/microsoft/scx /opt/microsoft/scx /var/opt/microsoft/scx \
                    /etc/opt/microsoft/*-cimprov /opt/microsoft/*-cimprov /var/opt/microsoft/*-cimprov
            fi

            check_if_pkg_is_installed omi
            if [ $? -ne 0 ]; then
                rm -rf /etc/opt/omi /opt/omi /var/opt/omi
            fi

            check_if_pkg_is_installed auoms
            if [ $? -ne 0 ]; then
                rm -rf /etc/opt/microsoft/auoms /opt/microsoft/auoms /var/opt/microsoft/auoms
            fi

            rmdir /etc/opt/microsoft /opt/microsoft /var/opt/microsoft > /dev/null 2>&1 || true
            rmdir /etc/opt /var/opt > /dev/null 2>&1 || true
        fi
    fi
    rm -f /etc/collectd.d/oms.conf > /dev/null 2>&1
    rm -f /etc/collectd/collectd.conf.d/oms.conf > /dev/null 2>&1
fi

if [ -n "${shouldexit}" ]
then
    # when extracting script/tarball don't also install
    cleanup_and_exit 0
fi

#
# Do stuff before extracting the binary here, for example test [ `id -u` -eq 0 ],
# validate space, platform, uninstall a previous version, backup config data, etc...
#

# Pre-flight if omsconfig installation will fail ...

if [ "$installMode" = "I" -o "$installMode" = "U" ]; then
    compare_install_type
    compare_arch

    python_ctypes_installed
    if [ $? -ne 0 ]; then
        if [ -z "${forceFlag}" ]; then
            echo "Error: Python is not configured or Python does not support ctypes on this system, installation cannot continue." >&2
            echo "Please install the ctypes package (python-ctypes)or upgrade Python to a newer version of python that comes with the ctypes module." >&2
            echo "You can check if the ctypes module is installed by starting python and running the command: 'import ctypes'." >&2
            echo "You can run this shell bundle with --force; in this case, we will install omsagent," >&2
            echo "but omsconfig (DSC configuration) will not be available and will need to be re-installed." >&2
            cleanup_and_exit $INSTALL_PYTHON_CTYPES
        else
            echo "Python is not configured or it does not support ctypes on this system, please upgrade Python to a newer version that comes with the ctypes module and re-install omsconfig later."
            echo "Installation will continue without installing omsconfig."
        fi
    fi

    install_if_program_does_not_exist_on_system tar
    if [ $? -ne 0 ]; then
        echo "tar was not installed, installation cannot continue. Please install tar."
        cleanup_and_exit $INSTALL_TAR
    fi

    install_if_program_does_not_exist_on_system sed
    if [ $? -ne 0 ]; then
        echo "sed was not installed, installation cannot continue. Please install sed."
        cleanup_and_exit $INSTALL_SED
    fi

    install_if_program_does_not_exist_on_system curl
    if [ $? -ne 0 ]; then
        if [ -z "${forceFlag}" ]; then
            echo "Error: curl was not installed, installation cannot continue."
            echo "You can run this shell bundle with --force; in this case, we will install omsagent,"
            echo "but omsconfig (DSC configuration) will not be available and will need to be re-installed."
            cleanup_and_exit $INSTALL_CURL
        else
            echo "curl was not installed, please install curl and re-install omsconfig (DSC configuration) later."
            echo "Installation will continue without installing omsconfig."
        fi
    fi

    check_if_program_exists_on_system gpg
    if [ $? -ne 0 ]; then
        echo "gpg is not installed, installation cannot continue."
        cleanup_and_exit $INSTALL_GPG
    fi
fi

#
# Extract the binary here.
#

echo "Extracting..."

tail -n +${SCRIPT_LEN_PLUS_ONE} "${SCRIPT}" | tar xzf -
STATUS=$?
if [ ${STATUS} -eq 127 ]
then
    echo "Failed: could not extract the install bundle. Exit code: 127"
    echo "Please make sure that tar is installed."
    cleanup_and_exit $INSTALL_TAR
elif [ ${STATUS} -ne 0 ]
then
    echo "Failed: could not extract the install bundle."
    cleanup_and_exit ${STATUS}
fi

if [ -n "${checkVersionAndCleanUp}" ]; then
    # scx (and omi) (this will print out the header)
    ./bundles/$SCX_INSTALLER --version-check

    # OMS agent itself
    versionInstalled=`getInstalledVersion omsagent`
    versionAvailable=`getVersionNumber $OMS_PKG omsagent-`
    if shouldInstall_omsagent; then shouldInstall="Yes"; else shouldInstall="No"; fi
    printf '%-15s%-15s%-15s%-15s\n' omsagent $versionInstalled $versionAvailable $shouldInstall

    # omsconfig
    versionInstalled=`getInstalledVersion omsconfig`
    versionAvailable=`getVersionNumber $DSC_PKG omsconfig-`    
    if shouldInstall_omsconfig; then shouldInstall="Yes"; else shouldInstall="No"; fi
    printf '%-15s%-15s%-15s%-15s\n' omsconfig $versionInstalled $versionAvailable "$shouldInstall"
    cleanup_and_exit 0
fi

#
# Do stuff after extracting the binary here, such as actually installing the package.
#

KIT_STATUS=0
BUNDLE_EXIT_STATUS=0

# Now do our installation work (or just exit)

case "$installMode" in
    E)
        # Files are extracted, so just exit
        cleanup_and_exit 0 "SAVE"
        ;;

    I)
        check_if_pkg_is_installed scx
        scx_installed=$?
        check_if_pkg_is_installed omi
        omi_installed=$?

        if [ $scx_installed -ne 0 -a $omi_installed -ne 0 ]; then
            echo "Installing OMS agent ..."

            pkg_add_list $OMS_PKG omsagent

            if shouldInstall_omsconfig; then pkg_add_list $DSC_PKG omsconfig; fi

            # Install SCX (and OMI)
            [ -n "${forceFlag}" ] && FORCE="--force" || FORCE=""
            [ -n "${debugMode}" ] && DEBUG="--debug" || DEBUG=""
            [ -n "${enableOMFlag}" ] && ENABLE_OM="--enable-opsmgr" || ENABLE_OM=""
            ./bundles/${SCX_INSTALLER} --install $FORCE $DEBUG $ENABLE_OM
            TEMP_STATUS=$?
            if [ $TEMP_STATUS -ne 0 ]; then
                echo "$SCX_INSTALLER package failed to install and exited with status $TEMP_STATUS"
                cleanup_and_exit $SCX_INSTALL_FAILED
            fi

            # Now actually install of the "queued" packages
            if [ -n "${add_list}" ]; then
                if [ "$INSTALLER" = "DPKG" ]; then
                    dpkg ${DPKG_CONF_QUALS} --install --refuse-downgrade ${add_list}
                else
                    rpm -ivh ${add_list}
                fi
                KIT_STATUS=$?
            else
                echo "----- No base kits to install -----"
            fi

            # Install bundled providers
            [ -n "${forceFlag}" ] && FORCE="--force" || FORCE=""
            echo "----- Installing bundled packages -----"
            for i in oss-kits/*-oss-test.sh; do
                # If filespec didn't expand, break out of loop
                [ ! -f $i ] && break

                # It's possible we have a test file without a kit; if so, ignore it
                OSS_BUNDLE=`basename $i -oss-test.sh`
                [ ! -f oss-kits/${OSS_BUNDLE}-cimprov-*.sh ] && continue

                ./$i
                if [ $? -eq 0 ]; then
                    ./oss-kits/${OSS_BUNDLE}-cimprov-*.sh --install $FORCE $restartDependencies
                    TEMP_STATUS=$?
                    if [ $TEMP_STATUS -ne 0 ]; then
                        echo "$OSS_BUNDLE provider package failed to install and exited with status $TEMP_STATUS"
                        BUNDLE_EXIT_STATUS=$SCX_KITS_INSTALL_FAILED
                    fi
                fi
            done
            for i in bundles/*-bundle-test.sh; do
                # If filespec didn't expand, break out of loop
                [ ! -f $i ] && break

                # It's possible we have a test file without bundle; if so, ignore it
                BUNDLE=`basename $i -bundle-test.sh`
                [ ! -f bundles/${BUNDLE}-*universal.*.sh ] && continue

                ./$i
                if [ $? -eq 0 ]; then
                    ./bundles/${BUNDLE}-*universal.*.sh --install $FORCE $restartDependencies
                    TEMP_STATUS=$?
                    if [ $TEMP_STATUS -ne 0 ]; then
                        echo "$BUNDLE package failed to install and exited with status $TEMP_STATUS"
                        BUNDLE_EXIT_STATUS=$BUNDLED_INSTALL_FAILED
                    fi
                fi
            done
        else
            echo "The omi or scx package is already installed. Please run the" >&2
            echo "installer with --upgrade (instead of --install) to continue." >&2
            KIT_STATUS=$USE_UPGRADE
        fi
        ;;

    U)
        echo "Updating OMS agent ..."

        shouldInstall_omsagent
        pkg_upd_list $OMS_PKG omsagent $?

        shouldInstall_omsconfig
        pkg_upd_list $DSC_PKG omsconfig $?

        # Install SCX (and OMI)
        [ -n "${forceFlag}" ] && FORCE="--force" || FORCE=""
        [ -n "${debugMode}" ] && DEBUG="--debug" || DEBUG=""
        [ -n "${enableOMFlag}" ] && ENABLE_OM="--enable-opsmgr" || ENABLE_OM=""
        ./bundles/${SCX_INSTALLER} --upgrade $FORCE $DEBUG $ENABLE_OM
        TEMP_STATUS=$?
        if [ $TEMP_STATUS -ne 0 ]; then
            echo "$SCX_INSTALLER package failed to upgrade and exited with status $TEMP_STATUS"
            cleanup_and_exit $SCX_INSTALL_FAILED
        fi

        # Now actually install of the "queued" packages
        if [ -n "${upd_list}" ]; then
            if [ "$INSTALLER" = "DPKG" ]; then
                [ -z "${forceFlag}" ] && FORCE="--refuse-downgrade" || FORCE=""
                dpkg ${DPKG_CONF_QUALS} --install $FORCE ${upd_list}
            else
                [ -n "${forceFlag}" ] && FORCE="--force" || FORCE=""
                rpm -Uvh $FORCE ${upd_list}
            fi
            KIT_STATUS=$?
        else
            echo "----- No base kits to update -----"
        fi
		
        if [ $KIT_STATUS -eq 0 ]; then
            # Remove fluentd conf for OMSConsistencyInvoker upon upgrade, if it exists
            rm -f /etc/opt/microsoft/omsagent/conf/omsagent.d/omsconfig.consistencyinvoker.conf

            # In case --upgrade is run without -w <id> and -s <key>
            if [ ! -f "$OMS_CONSISTENCY_INVOKER" ]; then
                echo "*/5 * * * * omsagent /opt/omi/bin/OMSConsistencyInvoker >/dev/null 2>&1" > $OMS_CONSISTENCY_INVOKER
            fi
            /opt/omi/bin/service_control restart
        fi

        # Upgrade bundled providers
        [ -n "${forceFlag}" ] && FORCE="--force" || FORCE=""
        echo "----- Updating bundled packages -----"
        for i in oss-kits/*-oss-test.sh; do
            # If filespec didn't expand, break out of loop
            [ ! -f $i ] && break

            # It's possible we have a test file without a kit; if so, ignore it
            OSS_BUNDLE=`basename $i -oss-test.sh`
            [ ! -f oss-kits/${OSS_BUNDLE}-cimprov-*.sh ] && continue

            ./$i
            if [ $? -eq 0 ]; then
                ./oss-kits/${OSS_BUNDLE}-cimprov-*.sh --upgrade $FORCE $restartDependencies
                TEMP_STATUS=$?
                if [ $TEMP_STATUS -ne 0 ]; then
                    echo "$OSS_BUNDLE provider package failed to upgrade and exited with status $TEMP_STATUS"
                    BUNDLE_EXIT_STATUS=$SCX_KITS_INSTALL_FAILED
                fi
            fi
        done
        for i in bundles/*-bundle-test.sh; do
            # If filespec didn't expand, break out of loop
            [ ! -f $i ] && break

            # It's possible we have a test file without bundle; if so, ignore it
            BUNDLE=`basename $i -bundle-test.sh`
            [ ! -f bundles/${BUNDLE}-*universal.*.sh ] && continue

            ./$i
            if [ $? -eq 0 ]; then
                ./bundles/${BUNDLE}-*universal.*.sh --upgrade $FORCE $restartDependencies
                TEMP_STATUS=$?
                if [ $TEMP_STATUS -ne 0 ]; then
                    echo "$BUNDLE package failed to upgrade and exited with status $TEMP_STATUS"
                    BUNDLE_EXIT_STATUS=$BUNDLED_INSTALL_FAILED
                fi
            fi
        done
        ;;

    *)
        echo "$0: Invalid setting of variable \$installMode, exiting" >&2
        cleanup_and_exit $INTERNAL_ERROR
esac

# Remove temporary files (now part of cleanup_and_exit) and exit

if [ "$KIT_STATUS" -ne 0 ]; then
    cleanup_and_exit ${KIT_STATUS}
elif [ "$BUNDLE_EXIT_STATUS" -ne 0 ]; then
    cleanup_and_exit ${BUNDLE_EXIT_STATUS}
else
    cleanup_and_exit 0
fi

#####>>- This must be the last line of this script, followed by a single empty line. -<<#####
