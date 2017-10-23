# 345678901234567890123456789012345678901234567890123456789012345678901234567890
# ## oms_standard_validation_library.sh

SHUTILSPATH=./shUtils/shUtils.sh
THISSCRIPT=oms_standard_validation_library.sh # Used by is_being_sourced procedure.

. $SHUTILSPATH

COMMONSEGMENT=/opt/microsoft/omsagent
BIN_DIR=$COMMONSEGMENT/bin
ETC_DIR=/etc$COMMONSEGMENT
VAR_DIR=/var$COMMONSEGMENT

# 345678901234567890123456789012345678901234567890123456789012345678901234567890
# ## Internal Methods

_new_workspaceVariables() {

    local _ws_id=$1

    local initial_conf_dir=
    if [ -z "$_ws_id" ]; then
        initial_conf_dir="$ETC_DIR/conf/omsadmin.conf"
    else
        initial_conf_dir="$ETC_DIR/$_ws_id/conf/omsadmin.conf"
    fi

    if [ "$_ws_id" = "scom" ]; then
        _validate_scomadmin_conf $initial_conf_dir
    else
        _validate_omsadmin_conf $initial_conf_dir
    fi
    . $initial_conf_dir

	### Setting Scriptwide (Not Env) variables

	WS_STATUS=0

	## Primary Locations

    ETC_DIR_WS=`validate_directory $ETC_DIR/$WORKSPACE_ID`
    VAR_DIR_WS=`validate_directory $VAR_DIR/$WORKSPACE_ID`

	## Secondary /etc Locations
    CERT_DIR=`validate_directory $ETC_DIR_WS/certs`
    CONF_DIR=`validate_directory $ETC_DIR_WS/conf`

	## Secondary /var Locations
    LOG_DIR=`validate_directory $VAR_DIR_WS/log`
    RUN_DIR=`validate_directory $VAR_DIR_WS/run`
    STATE_DIR=`validate_directory $VAR_DIR_WS/state`
    TMP_DIR=`validate_directory $VAR_DIR_WS/tmp`

	## Executable Files
    OMSAGENT_SCRIPTPATH=`validate_regular_file $BIN_DIR/omsagent`

	## Additional Files
    LOGFILE=`validate_regular_file $LOG_DIR/omsagent.log`
    CONFFILE=`validate_regular_file $CONF_DIR/omsagent.conf`

	## Temporal Files
    PIDFILE=$RUN_DIR/omsagent.pid
	SERVICE_REG_PATH=$CONF_DIR/.service_registered

    OMSAGENT_WS=omsagent-$WORKSPACE_ID
    OMSAGENT_WS_PATH=`validate_regular_file $BIN_DIR/$OMSAGENT_WS`

    if pidof systemd 1> /dev/null 2> /dev/null; then
        CMD_RESTART_OMSAGENT="/bin/systemctl restart $OMSAGENT_WS"
        CMD_START_OMSAGENT="/bin/systemctl start $OMSAGENT_WS"
        CMD_STOP_OMSAGENT="/bin/systemctl stop $OMSAGENT_WS"

		SYSTEMD_DIR=$(find_systemd_dir)
		OMSAGENT_SERVICE=$SYSTEMD_DIR/$OMSAGENT_WS.service
    else
        if [ -x /usr/sbin/invoke-rc.d ]; then
			CMD_RESTART_OMSAGENT="/usr/sbin/invoke-rc.d $OMSAGENT_WS restart"
			CMD_START_OMSAGENT="/usr/sbin/invoke-rc.d $OMSAGENT_WS start"
			CMD_STOP_OMSAGENT="/usr/sbin/invoke-rc.d $OMSAGENT_WS stop"
        elif [ -x /sbin/service ]; then
			CMD_RESTART_OMSAGENT="/sbin/service $OMSAGENT_WS restart"
			CMD_START_OMSAGENT="/sbin/service $OMSAGENT_WS start"
			CMD_STOP_OMSAGENT="/sbin/service $OMSAGENT_WS stop"
        elif [ -x /bin/systemctl ]; then
			CMD_RESTART_OMSAGENT="/bin/systemctl restart $OMSAGENT_WS"
			CMD_START_OMSAGENT="/bin/systemctl start $OMSAGENT_WS"
			CMD_STOP_OMSAGENT="/bin/systemctl stop $OMSAGENT_WS"
        else
            echo "FATAL:  Unrecognized service controller.  OS in unfamiliar or bad state." 1>&2
			WS_STATUS=9
			exit 9
        fi
		OMSAGENT_INITD=/etc/init.d/$OMSAGENT_WS
    fi
}

_validate_omsadmin_conf() {
    local _fSpec=$1
    local _boolOnly=$2
    VALIDATION_SUPPLEMENT_MESSAGE="Onboarding incorrect or incomplete."
    if [ -f $_fSpec ]; then
        validate_file_has_line_pattern $_fSpec "WORKSPACE_ID=$REGEX_UUID" $_boolOnly
        validate_file_has_line_pattern $_fSpec "AGENT_GUID=$REGEX_UUID" $_boolOnly
        validate_file_has_line_pattern $_fSpec "LOG_FACILITY=.*" $_boolOnly
        validate_file_has_line_pattern $_fSpec "CERTIFICATE_UPDATE_ENDPOINT=.*" $_boolOnly
        validate_file_has_line_pattern $_fSpec "URL_TLD=.*" $_boolOnly
        validate_file_has_line_pattern $_fSpec "DSC_ENDPOINT=.*" $_boolOnly
        validate_file_has_line_pattern $_fSpec "OMS_ENDPOINT=.*" $_boolOnly
        validate_file_has_line_pattern $_fSpec "AZURE_RESOURCE_ID=.*" $_boolOnly
        validate_file_has_line_pattern $_fSpec "OMSCLOUD_ID=.*" $_boolOnly
        validate_file_has_line_pattern $_fSpec "UUID=$REGEX_UUID" $_boolOnly
        return 0
    else
        if [ -z "$_boolOnly" ]; then
            echo "WARNING:  OMS Admin configuration file $OMSADMIN_CONF NOT Found!" >&2
            echo $VALIDATION_SUPPLEMENT_MESSAGE
        fi
        exit 2
    fi
}

_validate_omsadmin_disabled() {
	$BIN_DIR/omsadmin.sh -l | grep -E "Workspace: $WORKSPACE_ID *Status: Saved\(OMSAgent Not Registered, Workspace Configuration Saved\)" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR:  omsadmin.sh does NOT show a disabled state for workspace '$WORKSPACE_ID'." >&2
		exit 1
	fi
	return 0
}

_validate_omsadmin_running() {
	$BIN_DIR/omsadmin.sh -l | grep -E "Workspace: $WORKSPACE_ID *Status: Onboarded\(OMSAgent Running\)" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR:  omsadmin.sh does NOT show a normal running state for workspace '$WORKSPACE_ID'." >&2
		exit 1
	fi
	return 0
}

_validate_omsadmin_stopped() {
	$BIN_DIR/omsadmin.sh -l | grep -E "Workspace: *$WORKSPACE_ID *Status: Warning\(OMSAgent Registered, Not Running\)" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR:  omsadmin.sh does NOT show a stopped state for workspace '$WORKSPACE_ID'." >&2
		$BIN_DIR/omsadmin.sh -l | grep -E "Workspace: *$WORKSPACE_ID"
		echo "Workspace: $WORKSPACE_ID *Status: Warning(OMSAgent Registered, Not Running)"
		#exit 1
	fi
	return 0
}

_validate_pidfile_absent() {
    if [ -f "$PIDFILE" ]; then
		echo "ERROR:  $PIDFILE exists; CANNOT be a healthy stopped state." >&2
		exit 1
	fi
	return 0
}

_validate_pidfile_exists() {
    if [ ! -f "$PIDFILE" ]; then
		echo "ERROR:  NO $PIDFILE exists; CANNOT be a healthy started state." >&2
		exit 1
	fi
	return 0
}

_validate_primary_workspace() {
	$BIN_DIR/omsadmin.sh -l | grep -E "Primary Workspace: $WORKSPACE_ID" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR:  $WORKSPACE_ID is not the UUID for the primary workspace." >&2
		exit 1
	fi
	return 0
}

_validate_scomadmin_conf() {
    #### NOTE:  This routine is presently a wild guess.  XC
    local _fSpec=$1
    local _boolOnly=$2
    VALIDATION_SUPPLEMENT_MESSAGE="Onboarding incorrect or incomplete."
    if [ -f $_fSpec ]; then
        validate_file_has_line_pattern $_fSpec "WORKSPACE_ID=scom" $_boolOnly
        return 0
    else
        if [ -z "$_boolOnly" ]; then
            echo "WARNING:  SCOM Admin configuration file $OMSADMIN_CONF NOT Found!" >&2
            echo $VALIDATION_SUPPLEMENT_MESSAGE
        fi
        exit 2
    fi
}

_validate_service_registry_absent() {
    if [ -f "$SERVICE_REG_PATH" ]; then
		echo "ERROR:  Service registry file $SERVICE_REG_PATH exists; CANNOT be a healthy disabled state." >&2
		exit 1
	fi
	return 0
}

_validate_service_registry_exists() {
    if [ ! -f "$SERVICE_REG_PATH" ]; then
		echo "ERROR:  No service registry file $SERVICE_REG_PATH exists; CANNOT be a healthy enabled state." >&2
		exit 1
	fi
	return 0
}

# ### Interface Methods

validate_healthy_onboarded_state() {
    local _ws_id=$1
	_new_workspaceVariables $_ws_id
	return 0
}

validate_disable_state_healthy_onboarded() {
    local _ws_id=$1
	validate_healthy_onboarded_state $_ws_id
	_validate_pidfile_absent
	_validate_service_registry_absent
	_validate_omsadmin_disabled
	return 0
}

validate_primary_workspace_state_healthy_onboarded() {
    local _ws_id=$1
	validate_healthy_onboarded_state $_ws_id
	_validate_primary_workspace
	return 0
}

validate_running_state_healthy_onboarded() {
    local _ws_id=$1
	validate_healthy_onboarded_state $_ws_id
	_validate_pidfile_exists
	_validate_service_registry_exists
	_validate_omsadmin_running
	return 0
}

validate_stop_state_healthy_onboarded() {
    local _ws_id=$1
	validate_healthy_onboarded_state $_ws_id
	_validate_pidfile_absent
	_validate_service_registry_exists
	_validate_omsadmin_stopped
	return 0
}

# End of oms_standard_validation_library.sh
