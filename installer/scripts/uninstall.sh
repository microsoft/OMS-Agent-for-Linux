#!/bin/sh

#
# Uninstall script for OMS agent
#

installMode=R

if [ -n "$1" ]; then
    installMode=$1
fi

if [ "$installMode" != "R" -a "$installMode" != "P" ]; then
    echo "Invalid option specified: \"${installMode}\"; Valid modes: R (remove), P (purge)" 1>&2
    exit 1
fi

ulinux_detect_installer()
{
    INSTALLER=""

    # Detect based on distribution
    if [ -f "/etc/debian_version" ]; then # Ubuntu, Debian
        INSTALLER="DPKG"
    elif [ -f "/etc/redhat-release" ]; then # RHEL, CentOS, Oracle
        INSTALLER="RPM"
    elif [ -f "/etc/os-release" ]; then # Possibly SLES, openSUSE
        grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME=//g' | tr -d '="' | grep -qi suse
        if [ $? == 0 ]; then
            INSTALLER="RPM"
        fi
    fi

    # Fall back on detection via package manager availability
    if [ "$INSTALLER" = "" ]; then
        if [ -x "$(command -v dpkg)" ]; then
            INSTALLER="DPKG"
        elif [ -x "$(command -v rpm)" ]; then
            INSTALLER="RPM"
        fi
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
			# for OMI alone, always purge so that config is removed
			if [ "$1" = "omi" ]; then
				dpkg --purge ${1}
			else
				dpkg --remove ${1}
			fi
        fi
    else
        rpm --erase ${1}
    fi
    if [ $? -ne 0 ]; then
        echo "----- Ignore previous errors for package: $1 -----"
    fi	
}

# $1 - The name of the package to check as to whether it's installed
check_if_pkg_is_installed() {
    ulinux_detect_installer

    if [ "$INSTALLER" = "DPKG" ]; then
        dpkg -s $1 2> /dev/null | grep Status | egrep " installed| deinstall" 1> /dev/null
    else
        rpm -q $1 > /dev/null 2>&1
    fi

    return $?
}

# Do our stuff - uninstall the OMS agent

pkg_rm omsconfig

# If MDSD/LAD is installed and we're just removing (not purging), leave OMS, SCX and OMI
check_if_pkg_is_installed azsec-mdsd
azsec_mdsd_installed=$?
check_if_pkg_is_installed lad-mdsd
lad_mdsd_installed=$?

# if at least one of mdsd product is installed
MDSD_INSTALLED=$(( $azsec_mdsd_installed && $lad_mdsd_installed ))

# If LAD was installed don't remove omsagent, but proceed if purge mode was selected
if [ $lad_mdsd_installed -ne 0 -o "$installMode" = "P" ]; then
    pkg_rm omsagent
else
    echo "--- LAD detected; not removing OMS package ---"
    ws_conf_dir="/etc/opt/microsoft/omsagent/conf"
    primary_ws_id=''
    if [ -f ${ws_conf_dir}/omsadmin.conf ]; then
        primary_ws_id=`grep WORKSPACE_ID ${ws_conf_dir}/omsadmin.conf | cut -d= -f2`
    fi

    if [ "${primary_ws_id}" != "" -a "${primary_ws_id}" != "LAD" ]; then
        echo "--- Unboarding the workspace ${primary_ws_id}... ---"
        /opt/microsoft/omsagent/bin/omsadmin.sh -x ${primary_ws_id}
    fi
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
