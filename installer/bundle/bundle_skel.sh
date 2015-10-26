#! /bin/sh

#
# Shell Bundle installer package for the OMS project
#

# This script is a skeleton bundle file for ULINUX only for project OMS.

set -e
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

# These symbols will get replaced during the bundle creation process.

TAR_FILE=<TAR_FILE>
OMI_PKG=<OMI_PKG>
OMS_PKG=<OMS_PKG>
DSC_PKG=<DSC_PKG>
SCX_PKG=<SCX_PKG>
SCRIPT_LEN=<SCRIPT_LEN>
SCRIPT_LEN_PLUS_ONE=<SCRIPT_LEN+1>


usage()
{
    echo "usage: $1 [OPTIONS]"
    echo "Options:"
    echo "  --extract              Extract contents and exit."
    echo "  --force                Force upgrade (override version checks)."
    echo "  --install              Install the package from the system."
    echo "  --purge                Uninstall the package and remove all related data."
    echo "  --remove               Uninstall the package from the system."
    echo "  --restart-deps         Reconfigure and restart dependent service"
    echo "  --upgrade              Upgrade the package in the system."
    echo "  --debug                use shell debug mode."
    echo
    echo "  -w id, --id id         Use workspace ID <id> for automatic onboarding."
    echo "  -s key, --shared key   Use <key> as the shared key for automatic onboarding."
    echo
    echo "  -? | --help            shows this usage text."
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
    ulinux_detect_installer

    if [ "$INSTALLER" = "DPKG" ]; then
        dpkg -s $1 | grep Status | grep " installed" 2> /dev/null 1> /dev/null
    else
        rpm -q $1 2> /dev/null 1> /dev/null
    fi

    return $?
}

# $1 - The filename of the package to be installed
# $2 - The package name of the package to be installed (for future compatibility)
pkg_add() {
    pkg_filename=$1
    pkg_name=$2

    ulinux_detect_openssl_version
    pkg_filename=$TMPBINDIR/$pkg_filename

    ulinux_detect_installer
    echo "----- Installing package: $2 ($1) -----"
    if [ "$INSTALLER" = "DPKG" ]; then
        dpkg ${DPKG_CONF_QUALS} --install --refuse-downgrade ${pkg_filename}.deb
    else
        rpm --install ${pkg_filename}.rpm
    fi
}

# $1 - The package name of the package to be uninstalled
pkg_rm() {
    ulinux_detect_installer
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
pkg_upd() {
    pkg_filename=$1
    pkg_name=$2

    ulinux_detect_openssl_version
    pkg_filename=$TMPBINDIR/$pkg_filename

    ulinux_detect_installer
    echo "----- Updating package: $2 ($1) -----"
    if [ "$INSTALLER" = "DPKG" ]; then
        [ -z "${forceFlag}" -o "${pkg_name}" = "omi" ] && FORCE="--refuse-downgrade" || FORCE=""
        dpkg ${DPKG_CONF_QUALS} --install $FORCE ${pkg_filename}.deb

        export PATH=/usr/local/sbin:/usr/sbin:/sbin:$PATH
    else
        [ -n "${forceFlag}" -o "${pkg_name}" = "omi" ] && FORCE="--force" || FORCE=""
        rpm --upgrade $FORCE ${pkg_filename}.rpm
    fi
}


#
# Main script follows
#

onboardINT=0

while [ $# -ne 0 ]
do
    case "$1" in
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

        --int)
            onboardINT=1
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
            echo "EXTRACT DIR:     $EXTRACT_DIR" >&2
            echo "SCRIPT:          $SCRIPT" >&2
            echo >&2
            set -x
            shift 1
            ;;

        -? | --help)
            usage `basename $0` >&2
            cleanup_and_exit 0
            ;;

        *)
            usage `basename $0` >&2
            cleanup_and_exit 1
            ;;
    esac
done

if [ -z "${installMode}" ]; then
    echo "$0: No options specified, specify --help for help" >&2
    cleanup_and_exit 3
fi

ONBOARD_ERROR=0
[ -z "$onboardID" -a -n "$onboardKey" ] && ONBOARD_ERROR=1
[ -n "$onboardID" -a -z "$onboardKey" ] && ONBOARD_ERROR=1

if [ "$ONBOARD_ERROR" -ne 0 ]; then
    echo "Must specify both workspace ID (--id) and key (--shared) to onboard" 1>& 2
    exit 1
fi

if [ "$onboardINT" -ne 0 ]; then
    if [ -z "$onboardID" -o -z "$onboardKey" ]; then
        echo "Must specify both workspace ID (--id) and key (--shared) to internally onboard" 1>& 2
        exit 1
    fi
fi

if [ -n "$onboardID" -a -n "$onboardKey" ]; then
    verifyPrivileges "onboard"

    cat /dev/null > $ONBOARD_FILE
    chmod 600 $ONBOARD_FILE
    echo "WORKSPACE_ID=$onboardID" >> $ONBOARD_FILE
    echo "SHARED_KEY=$onboardKey" >> $ONBOARD_FILE

    if [ "$onboardINT" -ne 0 ]; then
        echo "URL_TLD=int2.microsoftatlanta-int" >> $ONBOARD_FILE
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
if [ "$installMode" = "R" -o "$installMode" = "P" ]
then
    pkg_rm omsconfig
    pkg_rm omsagent

    if [ -f /opt/microsoft/scx/bin/uninstall ]; then
        /opt/microsoft/scx/bin/uninstall $installMode
    else
        echo "SCX package is not installed"
    fi

    if [ "$installMode" = "P" ]
    then
        echo "Purging all files in cross-platform agent ..."
        rm -rf /etc/opt/microsoft/omsconfig /opt/microsoft/omsconfig /var/opt/microsoft/omsconfig \
            /etc/opt/microsoft/*-cimprov /etc/opt/microsoft/scx /etc/opt/microsoft/omsagent \
            /opt/microsoft/*-cimprov /opt/microsoft/scx /opt/microsoft/omsagent \
            /var/opt/microsoft/*-cimprov /var/opt/microsoft/scx /var/opt/microsoft/omsagent
        rmdir /etc/opt/microsoft /opt/microsoft /var/opt/microsoft > /dev/null 2> /dev/null || true

        # If OMI is not installed, purge its directories as well.
        check_if_pkg_is_installed omi
        if [ $? -ne 0 ]; then
            rm -rf /etc/opt/omi /opt/omi /var/opt/omi
        fi

        rmdir /etc/opt > /dev/null 2> /dev/null || true
    fi
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

EXIT_STATUS=0
SCX_EXIT_STATUS=0
OMI_EXIT_STATUS=0
OMS_EXIT_STATUS=0
DSC_EXIT_STATUS=0
BUNDLE_EXIT_STATUS=0

case "$installMode" in
    E)
        # Files are extracted, so just exit
        cleanup_and_exit 0 "SAVE"
        ;;

    I)
        echo "Installing OMS agent ..."
        check_if_pkg_is_installed omi
        if [ $? -eq 0 ]; then
            pkg_upd $OMI_PKG omi
            # It is acceptable that this fails due to the new omi being 
            # the same version (or less) than the one currently installed.
            OMI_EXIT_STATUS=0
        else
            pkg_add $OMI_PKG omi
            OMI_EXIT_STATUS=$?
        fi

        pkg_add $SCX_PKG scx
        SCX_EXIT_STATUS=$?

        pkg_add $OMS_PKG omsagent
        OMS_EXIT_STATUS=$?

        pkg_add $DSC_PKG omsconfig
        DSC_EXIT_STATUS=$?

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
        ;;

    U)
        echo "Updating OMS agent ..."
        check_if_pkg_is_installed omi
        if [ $? -eq 0 ]; then
            pkg_upd $OMI_PKG omi
            # It is acceptable that this fails due to the new omi being 
            # the same version (or less) than the one currently installed.
            OMI_EXIT_STATUS=0
        else
            pkg_add $OMI_PKG omi
            OMI_EXIT_STATUS=$?  
        fi

        pkg_upd $SCX_PKG scx
        SCX_EXIT_STATUS=$?

        pkg_upd $OMS_PKG omsagent
        OMS_EXIT_STATUS=$?

        pkg_upd $DSC_PKG omsconfig
        DSC_EXIT_STATUS=$?

        # Upgrade bundled providers
        #   Temporarily force upgrades via --force; this will unblock the test team
        #   This change may or may not be permanent; we'll see
        # [ -n "${forceFlag}" ] && FORCE="--force" || FORCE=""
        FORCE="--force"
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
        ;;

    *)
        echo "$0: Invalid setting of variable \$installMode, exiting" >&2
        cleanup_and_exit 2
esac

# Remove temporary files (now part of cleanup_and_exit) and exit

if [ "$OMS_EXIT_STATUS" -ne 0 -o "$DSC_EXIT_STATUS" -ne 0 -o "$SCX_EXIT_STATUS" -ne 0 -o "$OMI_EXIT_STATUS" -ne 0 -o "$BUNDLE_EXIT_STATUS" -ne 0 ]; then
    cleanup_and_exit 1
else
    cleanup_and_exit 0
fi

#####>>- This must be the last line of this script, followed by a single empty line. -<<#####
