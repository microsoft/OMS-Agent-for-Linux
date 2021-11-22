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
chown root:root $scriptPath

# Check if firewalld is present and running, open up destination port
tcp_port=8084
require_notify=true
echo "Checking if firewalld is present"
if [ -f /usr/bin/firewall-cmd ]; then
    echo "Firewalld present, checking state"
    firewalld_state=`firewall-cmd --state`
    if [ "$firewalld_state" == "running" ]; then
        echo "Firewalld is running, now opening port $tcp_port"
        res_open_port=`firewall-cmd --zone=public --add-port=$tcp_port/tcp --permanent`
        echo "Opening of port $tcp_port: " $res_open_port
        res_reloading_firewalld=`firewall-cmd --reload`
        echo "Reloading firewall rules: " $res_reloading_firewalld
        require_notify=false
    else
        echo "Firewalld is not running!"
    fi
else
    echo "Firewalld absent!"
fi

if $require_notify; then
    echo "Please configure your firewall (if running), to allow connections for destination port $tcp_port over TCP for NPM solution to run"
fi
