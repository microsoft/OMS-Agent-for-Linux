#!/bin/bash

rsyslog_configuration(){
    echo 'Checking for RSyslog installation'
    check_if_rsyslog_is_installed
}

check_if_rsyslog_is_installed() {
    if ps ax | grep -v grep | grep rsyslog > /dev/null
    then
        add_rsyslog_configuration_for_json
    else
        echo 'RSyslog is not installed.'
    fi
}

add_rsyslog_configuration_for_json(){
    file="/etc/rsyslog.d/00-vmware-oms.conf"

    echo 'module(load="imtcp")' > $file
    echo 'input(type="imtcp" port="1514")' >> $file
    echo '$template myFormat, "%timestamp:::date-year%-%timestamp:::date-month%-%timestamp:::date-day% %timestamp:::date-hour%:%timestamp:::date-minute%:%timestamp:::date-second% : %timereported:::date-year%-%timereported:::date-month%-%timereported:::date-day% %timereported:::date-hour%:%timereported:::date-minute%:%timereported:::date-second% : %hostname% : %fromhost-ip% : %syslogfacility% : %syslogseverity-text% : %programname% : %msg%\n"' >> $file
    echo '$template PerHostLog,"/var/log/vmware/esxi-syslog.log"' >> $file
    echo 'if $fromhost-ip != "127.0.0.1"'' then -?PerHostLog;myFormat' >> $file
    echo '& ~' >> $file

    if [ -f $file ];
    then
        echo 'RSyslog configuration updated.'
    else
        echo 'RSyslog configuration could not be updated. Try again later with valid permissions'
    fi   
}

rsyslog_configuration