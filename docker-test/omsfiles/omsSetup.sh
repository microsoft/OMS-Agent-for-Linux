disable_dsc()
{
    /opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py --disable

    if [ -f /etc/opt/omi/conf/omsconfig/configuration/Pending.mof ]; then
        rm /etc/opt/omi/conf/omsconfig/configuration/Pending.mof
    fi

    if [ -f /etc/opt/omi/conf/omsconfig/configuration/Current.mof ]; then
        rm /etc/opt/omi/conf/omsconfig/configuration/Current.mof
    fi
}

omsagent_setup()
{
    service rsyslog start
    /opt/omi/bin/omiserver -d
    copy_config_files
    disable_dsc
    restart_services
}

copy_config_files()
{
    dos2unix /home/temp/omsfiles/perf.conf
    dos2unix /home/temp/omsfiles/rsyslog-oms.conf
    cat /home/temp/omsfiles/perf.conf >> /etc/opt/microsoft/omsagent/conf/omsagent.conf
    cp /home/temp/omsfiles/rsyslog-oms.conf /etc/opt/omi/conf/omsconfig/rsyslog-oms.conf 
}

restart_services()
{
    /opt/omi/bin/service_control restart
    /opt/microsoft/omsagent/bin/service_control restart
}

get_status()
{
    /opt/microsoft/omsagent/bin/omsadmin.sh -l
    scxadmin -status
}

omsagent_setup
restart_services
get_status