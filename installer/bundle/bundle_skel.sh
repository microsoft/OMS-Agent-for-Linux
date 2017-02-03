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
OMI_PKG=<OMI_PKG>
OMS_PKG=<OMS_PKG>
DSC_PKG=<DSC_PKG>
SCX_PKG=<SCX_PKG>
INSTALL_TYPE=<INSTALL_TYPE>
SCRIPT_LEN=<SCRIPT_LEN>
SCRIPT_LEN_PLUS_ONE=<SCRIPT_LEN+1>

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
    echo "  --version                  Version of this shell bundle."
    echo "  --version-check            Check versions already installed to see if upgradable."
    echo "  --debug                    use shell debug mode."
    echo "  --collectd                 Enable collectd."
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
        exit $1
    else
        exit 0
    fi
}

check_version_installable() {
    # POSIX Semantic Version <= Test
    # Exit code 0 is true (i.e. installable).
    # Exit code non-zero means existing version is >= version to install.
    #
    # Parameter:
    #   Installed: "x.y.z.b" (like "4.2.2.135"), for major.minor.patch.build versions
    #   Available: "x.y.z.b" (like "4.2.2.135"), for major.minor.patch.build versions

    if [ $# -ne 2 ]; then
        echo "INTERNAL ERROR: Incorrect number of parameters passed to check_version_installable" >&2
        cleanup_and_exit 1
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
        cleanup_and_exit 1
    fi

    echo $1 | sed -e "s/$2//" -e 's/\.universal\..*//' -e 's/\.x64.*//' -e 's/\.x86.*//' -e 's/-/./'
}

verifyNoInstallationOption()
{
    if [ -n "${installMode}" ]; then
        echo "$0: Conflicting qualifiers, exiting" >&2
        cleanup_and_exit 1
    fi

    return;
}

verifyPrivileges() {
    # Parameter: desired operation (for meaningful output)
    if [ -z "$1" ]; then
        echo "verifyPrivileges missing required parameter (operation)" 1>& 2
        exit 1
    fi

    if [ `id -u` -ne 0 ]; then
        echo "Must have root privileges to be able to perform $1 operation" 1>& 2
        exit 1
    fi
}

ulinux_detect_openssl_version() {
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
        cleanup_and_exit 60
    fi
}

ulinux_detect_installer()
{
    INSTALLER=

    # If DPKG lives here, assume we use that. Otherwise we use RPM.
    which dpkg > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        INSTALLER=DPKG
    else
        INSTALLER=RPM
    fi
}

# $1 - The name of the package to check as to whether it's installed
check_if_pkg_is_installed() {
    if [ "$INSTALLER" = "DPKG" ]; then
        dpkg -s $1 2> /dev/null | grep Status | grep " installed" 1> /dev/null
    else
        rpm -q $1 2> /dev/null 1> /dev/null
    fi

    return $?
}

# $1 - The filename of the package to be installed
# $2 - The package name of the package to be installed (for future compatibility)
pkg_add_list() {
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
pkg_rm() {
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
}

# $1 - The filename of the package to be installed
# $2 - The package name of the package to be installed
# $3 - Okay to upgrade the package? (Optional)
pkg_upd_list() {
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
    if [ $(uname -m) = 'x86_64' ]; then
        echo "x64"
    else
        echo "x86"
    fi
}

compare_arch()
{
    #check if the user is trying to install the correct bundle (x64 vs. x86) 
    echo "Checking host architecture ..."
    AR=$(get_arch)
    
    case $OMS_PKG in
        *"$AR") 
            ;;
        *)         
            echo "Cannot install $OMS_PKG on ${AR} platform"
            cleanup_and_exit 1
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
           cleanup_and_exit 1
        fi
    fi
}

python_ctypes_installed() {
    # Check for Python ctypes library (required for omsconfig)

    hasCtypes=1
    tempFile=`mktemp`
    echo "Checking for ctypes python module ..."

    cat <<EOF > $tempFile
#! /usr/bin/python
import ctypes
EOF

    chmod u+x $tempFile
    $tempFile 1> /dev/null 2> /dev/null
    [ $? -eq 0 ] && hasCtypes=0
    rm $tempFile
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

shouldInstall_omi()
{
    local versionInstalled=`getInstalledVersion omi`
    [ "$versionInstalled" = "None" ] && return 0
    local versionAvailable=`getVersionNumber $OMI_PKG omi-`

    check_version_installable $versionInstalled $versionAvailable
}

shouldInstall_scx()
{
    local versionInstalled=`getInstalledVersion scx`
    [ "$versionInstalled" = "None" ] && return 0
    local versionAvailable=`getVersionNumber $SCX_PKG scx-cimprov-`

    check_version_installable $versionInstalled $versionAvailable
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
    # Package omsconfig will never install without Python ctypes ...
    if python_ctypes_installed 1> /dev/null 2> /dev/null; then
        local versionInstalled=`getInstalledVersion omsconfig`
        [ "$versionInstalled" = "None" ] && return 0
        local versionAvailable=`getVersionNumber $DSC_PKG omsconfig-`

        check_version_installable $versionInstalled $versionAvailable
    else
        return 1
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
            printf '%-15s%-15s%-15s%-15s\n\n' Package Installed Available Install?

            # omi
            versionInstalled=`getInstalledVersion omi`
            versionAvailable=`getVersionNumber $OMI_PKG omi-`
            if shouldInstall_omi; then shouldInstall="Yes"; else shouldInstall="No"; fi
            printf '%-15s%-15s%-15s%-15s\n' omi $versionInstalled $versionAvailable $shouldInstall

            # scx
            versionInstalled=`getInstalledVersion scx`
            versionAvailable=`getVersionNumber $SCX_PKG scx-cimprov-`
            if shouldInstall_scx; then shouldInstall="Yes"; else shouldInstall="No"; fi
            printf '%-15s%-15s%-15s%-15s\n' scx $versionInstalled $versionAvailable $shouldInstall

            # OMS agent itself
            versionInstalled=`getInstalledVersion omsagent`
            versionAvailable=`getVersionNumber $OMS_PKG omsagent-`
            if shouldInstall_omsagent; then shouldInstall="Yes"; else shouldInstall="No"; fi
            printf '%-15s%-15s%-15s%-15s\n' omsagent $versionInstalled $versionAvailable $shouldInstall

            # omsconfig
            versionInstalled=`getInstalledVersion omsconfig`
            versionAvailable=`getVersionNumber $DSC_PKG omsconfig-`
            if ! pytyon_ctypes_installed 1> /dev/null 2> /dev/null; then ctypes_text=" (No ctypes)"; fi
            if shouldInstall_omsconfig; then shouldInstall="Yes"; else shouldInstall="No${ctypes_text}"; fi
            printf '%-15s%-15s%-15s%-15s\n' omsconfig $versionInstalled $versionAvailable "$shouldInstall"

            exit 0
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
            echo "EXTRACT DIR:     $EXTRACT_DIR" >&2
            echo "SCRIPT:          $SCRIPT" >&2
            echo >&2
            set -x
            shift 1
            ;;

        --collectd)
            if [ -f /etc/collectd.conf -o -f /etc/collectd/collectd.conf ]; then
                touch /etc/collectd_marker.conf
            else
                echo "collectd.conf does not exist. Please make sure collectd is installed properly"
                cleanup_and_exit 1
            fi
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

        -\? | -h | --help)
            usage `basename $0` >&2
            cleanup_and_exit 0
            ;;

         *)
            echo "Unknown argument: '$1'" >&2
            echo "Use -h or --help for usage" >&2
            cleanup_and_exit 1
            ;;
    esac
done

if [ -z "${installMode}" ]; then
    echo "$0: No options specified, specify --help for help" >&2
    cleanup_and_exit 3
fi

ONBOARD_ERROR=0
[ -n "$topLevelDomain" ] && [ -z "$onboardID" -o -z "$onboardKey" ] && ONBOARD_ERROR=1
[ -z "$onboardID" -a -n "$onboardKey" ] && ONBOARD_ERROR=1
[ -n "$onboardID" -a -z "$onboardKey" ] && ONBOARD_ERROR=1

if [ "$ONBOARD_ERROR" -ne 0 ]; then
    echo "Must specify both workspace ID (--id) and key (--shared) to onboard" 1>& 2
    exit 1
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
    rm -f "$OMS_CONSISTENCY_INVOKER" > /dev/null 2> /dev/null 
    rm -f "$ONBOARD_FILE" > /dev/null 2> /dev/null
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

        if [ ! -d /var/lib/waagent/Microsoft.OSTCExtensions.LinuxDiagnostic-*/mdsd -o "$installMode" = "P" ]; then
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

            rmdir /etc/opt/microsoft /opt/microsoft /var/opt/microsoft > /dev/null 2> /dev/null || true
            rmdir /etc/opt /var/opt > /dev/null 2> /dev/null || true
        fi
    fi
    rm -f /etc/collectd.d/oms.conf > /dev/null 2> /dev/null
    rm -f /etc/collectd/collectd.conf.d/oms.conf > /dev/null 2> /dev/null
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
            echo "Python ctypes library was not found, installation cannot continue. Please" >&2
            echo "install the Python ctypes library or package (python-ctypes). If you wish," >&2
            echo "you can run this shell bundle with --force; in this case, we will install" >&2
            echo "omsagent, but omsconfig (DSC configuration) will not be available." >&2
            cleanup_and_exit 1
        else
            echo "Python ctypes library not found, will continue without installing omsconfig."
        fi
    fi
fi

#
# Extract the binary here.
#

echo "Extracting..."

tail -n +${SCRIPT_LEN_PLUS_ONE} "${SCRIPT}" | tar xzf -
STATUS=$?
if [ ${STATUS} -ne 0 ]
then
    echo "Failed: could not extract the install bundle."
    cleanup_and_exit ${STATUS}
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

            pkg_add_list $OMI_PKG omi
            pkg_add_list $SCX_PKG scx
            pkg_add_list $OMS_PKG omsagent

            python_ctypes_installed
            if [ $? -eq 0 ]; then
                pkg_add_list $DSC_PKG omsconfig
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
                    [ $TEMP_STATUS -ne 0 ] && BUNDLE_EXIT_STATUS="$TEMP_STATUS"
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
                    [ $TEMP_STATUS -ne 0 ] && BUNDLE_EXIT_STATUS="$TEMP_STATUS"
                fi
            done
        else
            echo "The omi or scx package is already installed. Please run the" >&2
            echo "installer with --upgrade (instead of --install) to continue." >&2
            KIT_STATUS=1
        fi
        ;;

    U)
        echo "Updating OMS agent ..."

        shouldInstall_omi
        pkg_upd_list $OMI_PKG omi $?

        shouldInstall_scx
        pkg_upd_list $SCX_PKG scx $?

        shouldInstall_omsagent
        pkg_upd_list $OMS_PKG omsagent $?

        python_ctypes_installed
        if [ $? -eq 0 ]; then
            shouldInstall_omsconfig
            pkg_upd_list $DSC_PKG omsconfig $?
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
                [ $TEMP_STATUS -ne 0 ] && BUNDLE_EXIT_STATUS="$TEMP_STATUS"
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
                [ $TEMP_STATUS -ne 0 ] && BUNDLE_EXIT_STATUS="$TEMP_STATUS"
            fi
        done
        ;;

    *)
        echo "$0: Invalid setting of variable \$installMode, exiting" >&2
        cleanup_and_exit 2
esac

# Remove temporary files (now part of cleanup_and_exit) and exit

if [ "$KIT_STATUS" -ne 0 -o "$BUNDLE_EXIT_STATUS" -ne 0 ]; then
    cleanup_and_exit 1
else
    cleanup_and_exit 0
fi

#####>>- This must be the last line of this script, followed by a single empty line. -<<#####
