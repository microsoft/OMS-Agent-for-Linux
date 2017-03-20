#!/bin/sh

RSYSLOG_TEMP=/etc/opt/microsoft/omsagent/sysconf/rsyslog.conf
SYSLOG_NG_TEMP=/etc/opt/microsoft/omsagent/sysconf/syslog-ng.conf

RSYSLOG_D=/etc/rsyslog.d

RSYSLOG_DEST=$RSYSLOG_D/95-omsagent.conf
OLD_RSYSLOG_DEST=/etc/rsyslog.conf

SYSLOG_NG_DEST=/etc/syslog-ng/syslog-ng.conf

OMS_SERVICE=/opt/microsoft/omsagent/bin/service_control

WORKSPACE_ID=
SYSLOG_PORT=

RestartService() {
    if [ -z "$1" ]; then
        echo "RestartService requires parameter (service name to restart)" 1>&2
        return 1
    fi

    echo "Restarting service: $1"

    # Does the service exist under systemd?
    local systemd_dir=$(${OMS_SERVICE} find-systemd-dir)
    pidof systemd 1> /dev/null 2> /dev/null
    if [ $? -eq 0 -a -f ${systemd_dir}/${1}.service ]; then
        /bin/systemctl restart $1
    else
        if [ -x /usr/sbin/invoke-rc.d ]; then
            /usr/sbin/invoke-rc.d $1 restart
        elif [ -x /sbin/service ]; then
            /sbin/service $1 restart
        elif [ -x /bin/systemctl ]; then
            /bin/systemctl restart $1
        else
            echo "Unrecognized service controller to start service $1" 1>&2
	    return 1
        fi
     fi
}

ConfigureRsyslog() {
    if [ ! -f ${RSYSLOG_DEST} ]; then
        # Rsyslog (new version) doesn't exist. Copy
        echo "Configuring rsyslog for OMS logging"

        cat ${RSYSLOG_TEMP} | sed "s/%WORKSPACE_ID%/${WORKSPACE_ID}/g" | sed "s/%SYSLOG_PORT%/${SYSLOG_PORT}/g" > ${RSYSLOG_DEST}
        chown omsagent:omiusers ${RSYSLOG_DEST}
        RestartService rsyslog
    else
        # Don't configure Rsyslog (new version) if the port is already configured
        egrep -q "@127.0.0.1:${SYSLOG_PORT}" ${RSYSLOG_DEST}
        if [ $? -ne 0 ]; then
            echo "Configuring rsyslog for OMS logging"

            cat ${RSYSLOG_TEMP} | sed "s/%WORKSPACE_ID%/${WORKSPACE_ID}/g" | sed "s/%SYSLOG_PORT%/${SYSLOG_PORT}/g" >> ${RSYSLOG_DEST}
            RestartService rsyslog
        fi
    fi
}

UnconfigureRsyslog() {
    if [ -f ${RSYSLOG_DEST} ]; then
        echo "Unconfiguring rsyslog for OMS logging"

        egrep -q "OMS Syslog collection for workspace ${WORKSPACE_ID}|@127.0.0.1:${SYSLOG_PORT}" ${RSYSLOG_DEST}
        if [ $? -eq 0 ]; then
            cp ${RSYSLOG_DEST} ${RSYSLOG_DEST}.bak
            egrep -v "OMS Syslog collection for workspace ${WORKSPACE_ID}|@127.0.0.1:${SYSLOG_PORT}" ${RSYSLOG_DEST}.bak > ${RSYSLOG_DEST}
            rm -f ${RSYSLOG_DEST}.bak 1> /dev/null 2> /dev/null
            RestartService rsyslog
        fi
    fi
}

PurgeRsyslog() {
    if [ -f ${RSYSLOG_DEST} ]; then
        echo "Purging rsyslog for OMS logging"

        rm -f ${RSYSLOG_DEST}
        RestartService rsyslog
    fi
}

ConfigureOldRsyslog() {
    # Don't configure Rsyslog (old version) if already configured (avoid duplicate entries)
    egrep -q "@127.0.0.1:${SYSLOG_PORT}" ${OLD_RSYSLOG_DEST}
    if [ $? -ne 0 ]; then
        echo "Configuring (old) rsyslog for OMS logging"

        cat ${RSYSLOG_TEMP} | sed "s/%WORKSPACE_ID%/${WORKSPACE_ID}/g" | sed "s/%SYSLOG_PORT%/${SYSLOG_PORT}/g" >> ${OLD_RSYSLOG_DEST}
        RestartService rsyslog
    fi
}

UnconfigureOldRsyslog() {
    egrep -q "OMS Syslog collection for workspace ${WORKSPACE_ID}|@127.0.0.1:${SYSLOG_PORT}" ${OLD_RSYSLOG_DEST}
    if [ $? -eq 0 ]; then
        echo "Unconfiguring (old) rsyslog for OMS logging"

        cp ${OLD_RSYSLOG_DEST} ${OLD_RSYSLOG_DEST}.bak
        egrep -v "OMS Syslog collection for workspace ${WORKSPACE_ID}|@127.0.0.1:${SYSLOG_PORT}" ${OLD_RSYSLOG_DEST}.bak > ${OLD_RSYSLOG_DEST}
        rm -f ${OLD_RSYSLOG_DEST}.bak 1> /dev/null 2> /dev/null
        RestartService rsyslog
    fi
}

PurgeOldRsyslog() {
    egrep -q "OMS Syslog collection|@127.0.0.1:25..." ${OLD_RSYSLOG_DEST}
    if [ $? -eq 0 ]; then
        echo "Purging (old) rsyslog for OMS logging"

        cp ${OLD_RSYSLOG_DEST} ${OLD_RSYSLOG_DEST}.bak
        egrep -v "OMS Syslog collection|@127.0.0.1:25..." ${OLD_RSYSLOG_DEST}.bak > ${OLD_RSYSLOG_DEST}
        rm -f ${OLD_RSYSLOG_DEST}.bak 1> /dev/null 2> /dev/null
        RestartService rsyslog
    fi
}

ConfigureSyslog_ng() {
    # Don't reconfigure syslog-ng if already configured (avoid duplicate entries)
    egrep -q "${WORKSPACE_ID}_oms" ${SYSLOG_NG_DEST}
    if [ $? -ne 0 ]; then
        echo "Configuring syslog-ng for OMS logging"

        local source=`grep '^source .*src' ${SYSLOG_NG_DEST} | cut -d ' ' -f2`
        if [ -z "${source}" ]; then
            source=src
        fi

        cat ${SYSLOG_NG_TEMP} | sed "s/%SOURCE%/${source}/g" | sed "s/%WORKSPACE_ID%/${WORKSPACE_ID}/g" | sed "s/%SYSLOG_PORT%/${SYSLOG_PORT}/g" >> ${SYSLOG_NG_DEST}
        RestartService syslog-ng
    fi
}

UnconfigureSyslog_ng() {
    egrep -q "${WORKDPACE_ID}_oms" ${SYSLOG_NG_DEST}
    if [ $? -eq 0 ]; then
        echo "Unconfiguring syslog-ng for OMS logging"

        cp ${SYSLOG_NG_DEST} ${SYSLOG_NG_DEST}.bak
        egrep -v "${WORKSPACE_ID}_oms" ${SYSLOG_NG_DEST}.bak > ${SYSLOG_NG_DEST}
        rm -f ${SYSLOG_NG_DEST}.bak 1> /dev/null 2> /dev/null
        RestartService syslog-ng
    fi
}

PurgeSyslog_ng() {
    egrep -q "_oms" ${SYSLOG_NG_DEST}
    if [ $? -eq 0 ]; then
        echo "Purging syslog-ng for OMS logging"

        cp ${SYSLOG_NG_DEST} ${SYSLOG_NG_DEST}.bak
        egrep -v "_oms" ${SYSLOG_NG_DEST}.bak > ${SYSLOG_NG_DEST}
        rm -f ${SYSLOG_NG_DEST}.bak 1> /dev/null 2> /dev/null
        RestartService syslog-ng
    fi
}

ConfigureSyslog() {
    if [ -f ${OLD_RSYSLOG_DEST} -a -d ${RSYSLOG_D} ]; then
        ConfigureRsyslog
    elif [ -f ${OLD_RSYSLOG_DEST} ]; then
        ConfigureOldRsyslog
    elif [ -f ${SYSLOG_NG_DEST} ]; then
        ConfigureSyslog_ng
    else
        echo "No supported syslog daemon found. Syslog messages will not be processed."
        return 1
    fi
}

UnconfigureSyslog() {
    if [ -f ${OLD_RSYSLOG_DEST} -a -d ${RSYSLOG_D} ]; then
        UnconfigureRsyslog
    elif [ -f ${OLD_RSYSLOG_DEST} ]; then
        UnconfigureOldRsyslog
    elif [ -f ${SYSLOG_NG_DEST} ]; then
        UnconfigureSyslog_ng
    else
        echo "No supported syslog daemon found; unable to unconfigure syslog monitoring."
        return 1
    fi
}

PurgeSyslog() {
    if [ -f ${OLD_RSYSLOG_DEST} -a -d ${RSYSLOG_D} ]; then
        PurgeRsyslog
    elif [ -f ${OLD_RSYSLOG_DEST} ]; then
        PurgeOldRsyslog
    elif [ -f ${SYSLOG_NG_DEST} ]; then
        PurgeSyslog_ng
    else
        echo "No supported syslog daemon found; unable to purge syslog monitoring."
        return 1
    fi
}

RestartSyslog() {
    if [ -f ${OLD_RSYSLOG_DEST} -a -d ${RSYSLOG_D} ]; then
        RestartService rsyslog
    elif [ -f ${OLD_RSYSLOG_DEST} ]; then
        RestartService rsyslog
    elif [ -f ${SYSLOG_NG_DEST} ]; then
        RestartService syslog-ng
    else
        echo "No supported syslog daemon found; unable to restart syslog monitoring."
        return 1
    fi
}

SetVariables() {
    WORKSPACE_ID=$1
    SYSLOG_PORT=$2

    if [ -z $WORKSPACE_ID -o -z $SYSLOG_PORT ]; then
        echo "WORKSPACE_ID and SYSLOG_PORT are required" 1>&2
        exit 1
    fi

    if [ "$WORKSPACE_ID" = "LAD" ]; then
        RSYSLOG_TEMP=/etc/opt/microsoft/omsagent/sysconf/rsyslog-lad.conf
        SYSLOG_NG_TEMP=/etc/opt/microsoft/omsagent/sysconf/syslog-ng-lad.conf
    fi
}

case "$1" in
    configure)
        SetVariables $2 $3
        ConfigureSyslog || exit 1
        ;;

    unconfigure)
        SetVariables $2 $3
        UnconfigureSyslog || exit 1
        ;;

    purge)
        PurgeSyslog || exit 1
        ;;

    restart)
        RestartSyslog || exit 1
        ;;

    *)
        echo "Unknown parameter : $1" 1>&2
        exit 1
        ;;
esac

