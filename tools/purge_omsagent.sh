#! /bin/bash

SOLO_LAD_DIR=/var/lib/waagent/Microsoft.Azure.Diagnostics.LinuxDiagnostic-*
OMS_LAD_DIR=/var/opt/microsoft/omsagent/LAD

OMS_ONBOARD_AGENT=onboard_agent.sh

WAAGENT_DIR=/var/lib/waagent
WAAGENT_XML=$WAAGENT_DIR/Microsoft.EnterpriseCloud.Monitoring.OmsAgentForLinux.*.manifest.xml

STOPPED_WAAGENT=0

# error codes
UNSUPPORTED_PKG_INSTALLER=66
UNSUPPORTED_SERVICE_CONTROLLER=67
UNSUPPORTED_WAAGENT_NAME=68
ONBOARD_AGENT_MISSING=69


# $1 - exit status
call_exit()
{
    echo "Purge script exiting with code $1"
    exit $1
}

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

    if [ "$INSTALLER" = "" ]; then
        echo "Error: This system does not have a supported package manager" >&2
        echo "Supported Sytems: 'DPKG' & 'RPM'" >&2
        echo "Cannot purge without a supported package manager" >&2
        call_exit $UNSUPPORTED_PKG_INSTALLER
    fi
}

ulinux_detect_servicecontroller()
{
    CONTROLLER=""

    # Detect based on systemd
    if which systemctl > /dev/null 2>&1; then
        CONTROLLER="systemctl"
    # Fall back on detection via filepath
    else
        if   [ -f "/bin/systemctl" ]; then
            CONTROLLER="systemctl"
        elif [ -f "/sbin/service" ]; then
            CONTROLLER="service"
        elif [ -f "/usr/sbin/invoke-rc.d" ]; then
            CONTROLLER="invoke-rc.d"
        fi
    fi

    if [ "$CONTROLLER" = "" ]; then
        echo "Error: This system does not have a supported service controller" >&2
        echo "Supported Systems: 'systemctl', 'service', and 'invoke-rc'" >&2
        echo "Cannot purge without a supported service controller" >&2
        call_exit $UNSUPPORTED_SERVICE_CONTROLLER
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

# $1 - The name of the package to be uninstalled
pkg_rm()
{
    if [ "$1" != "" ]; then
        echo "----- Removing package: $1 -----"
        if [ "$INSTALLER" = "DPKG" ]; then
            dpkg --purge ${1}
        else
            rpm --erase ${1}
        fi
        if [ $? -ne 0 ]; then
            echo "----- Ignore previous errors for package: $1 -----"
        fi
    fi
}

check_service_running()
{
    if [ "$CONTROLLER" = "systemctl" ]; then
        systemctl status $WAAGENT_NAME 2> /dev/null | grep Active | grep " active (running)" 1> /dev/null
    elif [ "$CONTROLLER" = "service" ]; then
        service $WAAGENT_NAME status 2> /dev/null | grep $1 | grep "is running..." 1> /dev/null
    else
        invoke-rc.d $WAAGENT_NAME status 2> /dev/null | grep $1 | grep "start/running" 1> /dev/null
    fi

    return $?
}

check_waagent_name()
{
    WAAGENT_NAME=""

    if [ "$CONTROLLER" = "systemctl" ]; then
        if systemctl status waagent > /dev/null 2>&1; then
            WAAGENT_NAME="waagent"
        elif systemctl status walinuxagent > /dev/null 2>&1; then
            WAAGENT_NAME="walinuxagent"
        fi
    else
        if $CONTROLLER waagent status > /dev/null 2>&1; then
            WAAGENT_NAME="waagent"
        elif $CONTROLLER walinuxagent status > /dev/null 2>&1; then
            WAAGENT_NAME="walinuxagent"
        fi
    fi

    if [ "$WAAGENT_NAME" = "" ]; then
        echo "Error: This system does not have a recognized version of waagent" >&2
        echo "Supported Version Names: 'waagent' and 'walinuxagent'" >&2
        echo "Cannot purge without a recognized version of waagent" >&2
        call_exit $UNSUPPORTED_WAAGENT_NAME
    fi
}

stop_waagent()
{
    if check_service_running; then
        if [ "$CONTROLLER" = "systemctl" ]; then
            systemctl stop $WAAGENT_NAME
        else
            $CONTROLLER $WAAGENT_NAME stop
        fi

        if [ $? -ne 0 ]; then
            echo "----- ERROR OCCURRED -----"
            echo "Error in stopping waagent"
        else
            STOPPED_WAAGENT=1
        fi
    fi
}

restart_waagent()
{
    if [ $STOPPED_WAAGENT -eq 1 ]; then
        if [ "$CONTROLLER" = "systemctl" ]; then
            systemctl restart $WAAGENT_NAME
        else
            $CONTROLLER $WAAGENT_NAME restart
        fi

        if [ $? -ne 0 ]; then
            echo "----- ERROR OCCURRED -----"
            echo "Error in restarting waagent"
        else
            STOPPED_WAAGENT=0
        fi
    fi
}

# $1 - The name of the user to be removed (if it exists)
user_rm()
{
    if id $1 > /dev/null 2>&1; then
        echo "----- Removing user: $1 -----"
        userdel -r $1
    fi
    if [ $? -ne 0 ]; then
        echo "----- Ignore previous errors for removing user: $1 -----"
    fi
}

# $1 - The name of the group to be removed (if it exists)
group_rm()
{
    if id -g $1 > /dev/null 2>&1; then
        echo "----- Removing group: $1 -----"
        groupdel $1
    fi
    if [ $? -ne 0 ]; then
        echo "----- Ignore previous errors for removing group: $1 -----"
    fi
}

# $1 - The name of the directory to delete (if it exists)
# $2 - The name of the package associated with the directory
dir_rm()
{
    if [ -d $1 ]; then
        pkg_rm $2
        if [ -d $1 ]; then
            rm -rf $1
        fi
    fi
}



##### PURGE SCRIPT FOLLOWS #####



ulinux_detect_installer
ulinux_detect_servicecontroller
check_waagent_name

# REMOVE LAD
check_if_pkg_is_installed lad-mdsd
LAD_MDSD_INSTALLED=$?
if [ $LAD_MDSD_INSTALLED -eq 0 ]; then
    echo "--------------------------------------------------------------------------------"
    echo "WARNING: LAD is currently installed on the machine."
    echo "  Purging OMS without purging LAD may not fully succeed, because LAD has a dependency on OMS."
    echo "  In order to successfully purge OMS, LAD must be purged as well."
    while : ; do
        read -p "Do you wish to continue with purging? (y/n)" continue_lad
        if [ "$continue_lad" = "y" ]; then
            echo "Continuing with purge..."
            echo "--------------------------------------------------------------------------------"
            break
        elif [ "$continue_lad" = "n" ]; then
            echo "Exiting without purging..."
            call_exit 0
        else
            echo "Unknown input. Please type 'y' (yes) or 'n' (no) to proceed."
        fi
    done

    # continuing with LAD purge
    echo "Please go to portal.azure.com and uninstall the LAD extension."
    echo "Go to Azure Portal -> Virtual Machines -> <vm_name> -> Settings -> Extensions"
    echo "and then click the '...' in the LinuxDiagnostic row and click 'Uninstall'"
    read -p "Press enter to proceed once the Extension is uninstalled." toss2
    echo ""

    # remove LAD directories
    echo "---------- Removing LAD directories ----------"
    if [ -d $SOLO_LAD_DIR ]; then
        rm -rf $SOLO_LAD_DIR
    fi
    if [ -d $OMS_LAD_DIR ]; then
        rm -rf $OMS_LAD_DIR
    fi

    # remove LAD package
    echo "---------- Removing LAD package ----------"
    pkg_rm lad-mdsd

    # remove MDSD package
    check_if_pkg_is_installed mdsd
    MDSD_INSTALLED=$?
    if [ $MDSD_INSTALLED -eq 0 ]; then
        echo "---------- Removing MDSD package ----------"
        pkg_rm mdsd
    fi

    echo "LAD successfully purged!"
fi


# REMOVE OMS
echo "--------------------------------------------------------------------------------"
echo "------------------------------ STARTING OMS PURGE ------------------------------"
echo "--------------------------------------------------------------------------------"
echo ""

# Check if installed via extension
ls /var/lib/waagent | grep -i Microsoft.EnterpriseCloud.Monitoring.OmsAgentForLinux- > /dev/null 2>&1
EXTENSION_INSTALLED=$?
if [ $EXTENSION_INSTALLED -eq 0 ]; then
    echo ""
    echo "Please go to portal.azure.com and uninstall the OMS extension and its dependencies."
    echo "Go to Azure Portal -> Virtual Machines -> <vm_name> -> Settings -> Extensions"
    echo "and then click the '...' in the OMSAgentForLinux row and click 'Uninstall'"
    echo "(Do this as well with the DependencyAgentLinux row)"
    read -p "Press enter to proceed once the Extension is uninstalled." toss2
    echo ""
fi

# run OMS purge command
echo "---------- Downloading OMS Onboarding Script ----------"
if [ ! -f $OMS_ONBOARD_AGENT ]; then
    wget https://raw.githubusercontent.com/Microsoft/OMS-Agent-for-Linux/master/installer/scripts/onboard_agent.sh
    if [ $? -ne 0 ]; then
        echo "Error accessing Github to download the purge script for the OMS Agent" >&2
        echo "Please ensure that this machine can connect to the following URL:" >&2
        echo "  https://raw.githubusercontent.com/Microsoft/OMS-Agent-for-Linux/master/installer/scripts/onboard_agent.sh" >&2
        echo "Or ensure the onboard_agent.sh script is available in the same directory as this script." >&2
        call_exit $ONBOARD_AGENT_MISSING
    fi
fi
echo ""

echo "---------- Running OMS Purge Script ----------"
chmod +x ./onboard_agent.sh
./onboard_agent.sh --purge

# remove OMS Extension info

if [ -f $WAAGENT_XML ]; then
    STOPPED_WAAGENT=1
    echo "Temporarily stopping waagent..."
    stop_waagent

    echo "Removing OMS Extension files..."
    rm -rf $WAAGENT_XML
fi

# remove directories (if they exist)
echo "---------- Removing all relevant directories ----------"
dir_rm /etc/opt/microsoft/auoms auoms
dir_rm /etc/opt/microsoft/dependency-agent dependency-agent
dir_rm /etc/opt/microsoft/omsagent omsagent
dir_rm /etc/opt/microsoft/scx scx
if [ ! "$(ls -A /etc/opt/microsoft > /dev/null 2>&1)" ]; then
    dir_rm /etc/opt/microsoft
fi

dir_rm /opt/microsoft/auoms auoms
dir_rm /opt/microsoft/dependency-agent dependency-agent
dir_rm /opt/microsoft/omsagent omsagent
dir_rm /opt/microsoft/omsconfig omsconfig
dir_rm /opt/microsoft/scx scx
if [ ! "$(ls -A /opt/microsoft > /dev/null 2>&1)" ]; then
    dir_rm /opt/microsoft
fi

dir_rm /var/opt/microsoft/auoms auoms
dir_rm /var/opt/microsoft/dependency-agent dependency-agent
dir_rm /var/opt/microsoft/omsagent omsagent
dir_rm /var/opt/microsoft/omsconfig omsconfig
dir_rm /var/opt/microsoft/scx scx
if [ ! "$(ls -A /var/opt/microsoft > /dev/null 2>&1)" ]; then
    dir_rm /var/opt/microsoft
fi

if [ $EXTENSION_INSTALLED -eq 0 ]; then
    dir_rm /var/lib/waagent/Microsoft.EnterpriseCloud.Monitoring.OmsAgentForLinux-*
fi

echo ""

echo "---------- Removing Users and Groups ----------"
user_rm omsagent
user_rm omi
user_rm nxautomation

group_rm omiusers
group_rm omi
group_rm omsagent
group_rm nxautomation
echo ""

if [ $STOPPED_WAAGENT -eq 1 ]; then
    echo "Restarting waagent..."
    restart_waagent
fi

echo ""
echo "--------------------------------------------------------------------------------"
echo "OMS Agent should be fully purged!"
echo "(If you see a lot of errors above, try running the script again.)"
echo "In order to reinstall the agent, either:"
echo "  - Wait for Azure Security Center to provision the VM (if it is active)"
echo "  - Manually connect the VM to the workspace (Azure Log Analytics - > Workspace -> Virtual Machines -> VM_name -> Connect)"
echo "  - Install+onboard via shell bundle using the onboard_agent.sh file downloaded:"
echo "    $ sudo ./onboard_agent.sh -w <workspace_id> -s <shared_key>"
echo "Thank you!"