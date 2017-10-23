#! /bin/sh
# report1_oms_validations.sh

export BIN_DIR=/opt/microsoft/omsagent/bin

PrimaryWSID=`./assure_install_unit_test_state.sh`
. ./oms_standard_validation_library.sh


if [ -z "$PrimaryWSID" ]; then
	echo "FATAL:  Must have valid PrimaryWSID value for unit testing on installed area."
	echo "Value seen was '$PrimaryWSID'."
	return 99
else
	echo "Using PrimaryWSID of $PrimaryWSID for unit tests."
fi

# ## Initializations

_iterations=8

if [ -n "$1" ]; then
	_iterations=$1
fi

i=1
echo "Begin Start test at $(date)."
_new_workspaceVariables $PrimaryWSID
$BIN_DIR/service_control stop $PrimaryWSID
validate_stop_state_healthy_onboarded $PrimaryWSID
$BIN_DIR/service_control start $PrimaryWSID
while [ $i -le $_iterations ]; do
	echo ">>> Begin try $i of $_iterations"
    if [ ! -f "$PIDFILE" ]; then
		echo "INFO:  PIDFILE $PIDFILE does not yet exist."
	fi
    if [ ! -f "$SERVICE_REG_PATH" ]; then
		echo "INFO:  Service Registration File $SERVICE_REG_PATH does not yet exist."
	fi
	$BIN_DIR/omsadmin.sh -l | grep -E "Workspace: $WORKSPACE_ID *Status: Onboarded\(OMSAgent Running\)" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "INFO:  omsadmin does not yet see $WORKSPACE_ID in a healthy running state."
	fi
	sleep 1
	i=`expr $i + 1`
done
echo ">>> End of $_iterations tries at $(date)."

# End of report1_oms_validations.sh
