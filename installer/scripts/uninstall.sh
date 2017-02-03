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
    INSTALLER=

    # If DPKG lives here, assume we use that. Otherwise we use RPM.
    which dpkg > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        INSTALLER=DPKG
    else
        INSTALLER=RPM
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

# $1 - The name of the package to check as to whether it's installed
check_if_pkg_is_installed() {
    ulinux_detect_installer

    if [ "$INSTALLER" = "DPKG" ]; then
        dpkg -s $1 2> /dev/null | grep Status | egrep " installed| deinstall" 1> /dev/null
    else
        rpm -q $1 2> /dev/null 1> /dev/null
    fi

    return $?
}

# Do our stuff - uninstall the OMS agent

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
