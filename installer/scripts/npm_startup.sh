# This scripts onboards NPMD solution to omsagent node
#Usage:
# For Ubuntu and CentOs use 'sudo sh npm_startup.sh'
# For RHEL use 'sh npm_startup.sh'

cmd="# NPMD\nomsagent ALL=(ALL) NOPASSWD: /opt/microsoft/omsconfig/Scripts/NPMAgentBinaryCap.sh"
scriptPath="/opt/microsoft/omsconfig/Scripts/NPMAgentBinaryCap.sh"

SudoSupportsIncludeDirective() {
    # Algorithm:
    #   If    '#includedir /etc/sudoers.d' exists in /etc/sudoers AND /etc/sudoers.d exists,
    #   Then  Use /etc/sudoers.d
    #   Else  Append to /etc/sudoers

    INCLUDEDIR=0
    egrep -q "^#includedir\s+/etc/sudoers.d" /etc/sudoers && INCLUDEDIR=1

    if [ $INCLUDEDIR -eq 1 -a -d /etc/sudoers.d ]; then
        return 0
    else
        return 1
    fi
}

# Add file to sudoers list
SudoSupportsIncludeDirective
if [ $? -eq 0 ]; then
    chmod 640 /etc/sudoers.d/omsagent
    cp /etc/sudoers.d/omsagent /etc/sudoers.d/omsagent.bak
    sed "/# End sudo configuration for omsagent/i $cmd" /etc/sudoers.d/omsagent.bak > /etc/sudoers.d/omsagent
    rm -rf /etc/sudoers.d/omsagent.bak
    chmod 440 /etc/sudoers.d/omsagent
else
    cp /etc/sudoers /etc/sudoers.bak
    sed "/# End sudo configuration for omsagent/i $cmd" /etc/sudoers.bak > /etc/sudoers
    rm -rf /etc/sudoers.bak
fi

# Create script file
su - omsagent -c "echo $'chmod 755 \$1\nsetcap cap_net_raw=ep \$1' > $scriptPath"
chmod 755 $scriptPath

# Add firewalld TCP rule on CentOS 7 or RHEL 7
tcp_port=8084
release_file=/etc/os-release
str_centOS7="CentOS Linux 7"
str_rhel7="Red Hat Enterprise Linux Server 7.0"
require_notify=1
if [ -f $release_file ];
then
        pretty_name=`cat $release_file | grep PRETTY_NAME=`
        if [ "${pretty_name#*$str_centOS7}" != "$pretty_name" -o "${pretty_name#*$str_rhel7}" != "$pretty_name" ];
        then
                echo "Checking firewalld"
                if [ -f /usr/bin/firewall-cmd ];
                then
                        echo "Checking to see if firewall port $tcp_port can be opened"
                        firewalld_state=`firewall-cmd --state`
                        if [ "$firewalld_state" == "running" ];
                        then
                                res_open_port=`firewall-cmd --zone=public --add-port=$tcp_port/tcp --permanent`
                                echo "Opening of port $tcp_port: " $res_open_port
                                res_reloading_firewalld=`firewall-cmd --reload`
                                echo "Reloading firewall rules: " $res_reloading_firewalld
                                require_notify=0
                        else
                            echo "Firewalld is not running!"
                        fi
                else
                        echo "Firewalld found absent!"
                fi
        fi
else
        echo "File $release_file not found!"
fi

if [ $require_notify -eq 1 ];
then
    echo "Please configure your firewall (if running), to allow connections for destination port $tcp_port over TCP for NPM solution to run"
fi
