#!/bin/bash

rsyslog_configuration(){
    echo 'Checking for RSyslog installation'
    check_if_rsyslog_is_installed
}

check_if_rsyslog_is_installed() {
    if ps ax | grep -v grep | grep rsyslog > /dev/null
    then
        add_rsyslog_configuration
    else
        echo 'RSyslog is not installed.'
    fi
}

add_rsyslog_configuration(){
    file="/etc/rsyslog.d/96-vmware-oms.conf"
    listen_port="1514"
    log_path="/var/log/vmware"
    log_file="esxi-syslog.log"

    sudo mkdir $log_path
    sudo touch "$log_path/$log_file"
    sudo chmod 644 "$log_path/$log_file"
    echo 'module(load="imtcp")' > $file
    echo 'input(type="imtcp" port="'$listen_port'")' >> $file
    echo '$template myFormat, "%timestamp:::date-year%-%timestamp:::date-month%-%timestamp:::date-day% %timestamp:::date-hour%:%timestamp:::date-minute%:%timestamp:::date-second% : %timereported:::date-year%-%timereported:::date-month%-%timereported:::date-day% %timereported:::date-hour%:%timereported:::date-minute%:%timereported:::date-second% : %hostname% : %fromhost-ip% : %syslogfacility% : %syslogseverity-text% : %programname% : %msg%\n"' >> $file
    echo '$template PerHostLog,"'$log_path'/'$log_file'"' >> $file
    echo 'if $fromhost-ip != "127.0.0.1"'' then -?PerHostLog;myFormat' >> $file
    echo '& ~' >> $file

    if [ -f $file ];
    then
        sudo service rsyslog restart
        add_logrotate_configuration $log_path $log_file
        echo 'RSyslog configuration updated.'
    else
        echo 'RSyslog configuration could not be updated. Try again later with valid permissions'
    fi
}

add_logrotate_configuration(){
    file="/etc/logrotate.d/vmware-oms"

    echo "$1/$2 {" > $file
    echo '    rotate 5' >> $file
    echo '    missingok' >> $file
    echo '    notifempty' >> $file
    echo '    create 644 syslog adm' >> $file
    echo '    compress' >> $file
    echo '    size 50M' >> $file
    echo '    copytruncate' >> $file
    echo '}' >> $file

    if [ -f $file ];
    then
        logrotate -d $file
        echo 'Logrotate configuration updated.'
    else
        echo 'Logrotate configuration could not be updated. Try again later with valid permissions'
    fi
}

rsyslog_configuration