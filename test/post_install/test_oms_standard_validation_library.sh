#! /bin/sh
# test_oms_standard_validation_library.sh

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


# ### Interface Tests

test_validate_healthy_onboarded_state() {
	validate_healthy_onboarded_state
	assertEquals 0 $?
	validate_healthy_onboarded_state $PrimaryWSID
	assertEquals 0 $?
	stdoutr=`validate_healthy_onboarded_state scom 2>/dev/null`
	assertNotEquals 0 $?
	return 0
}

test_validate_primary_workspace_state_healthy_onboarded() {
	validate_primary_workspace_state_healthy_onboarded
	assertEquals 0 $?
	validate_primary_workspace_state_healthy_onboarded $PrimaryWSID
	assertEquals 0 $?
	NonPrimaryWSID=`$BIN_DIR/omsadmin.sh -l | grep '^Workspace: [^ ]' | tail -1 | sed 's/Workspace: //' | sed 's/ *Status: *.*//'`
	`validate_primary_workspace_state_healthy_onboarded $NonPrimaryWSID 2>/dev/null`
	assertNotEquals 0 $?
	return 0
}

test_validate_running_state_healthy_onboarded() {
	validate_running_state_healthy_onboarded
	assertEquals 0 $?
	validate_running_state_healthy_onboarded $PrimaryWSID >/dev/null 2>/dev/null
	assertEquals 0 $?
	$BIN_DIR/service_control stop $PrimaryWSID >/dev/null 2>/dev/null
	assertEquals 0 $?
	sleep 1
	`validate_running_state_healthy_onboarded 2>/dev/null`
	assertEquals 1 $?
	`validate_running_state_healthy_onboarded $PrimaryWSID 2>/dev/null`
	assertEquals 1 $?
	$BIN_DIR/service_control start $PrimaryWSID >/dev/null 2>/dev/null
	assertEquals 0 $?
	sleep 1
	return 0
}

test_validate_stop_state_healthy_onboarded() {
	
	$BIN_DIR/service_control stop $PrimaryWSID >/dev/null 2>/dev/null
	assertEquals 0 $?
	validate_stop_state_healthy_onboarded >/dev/null 2>/dev/null
	assertEquals 0 $?
	validate_stop_state_healthy_onboarded $Primary_WSID >/dev/null 2>/dev/null
	assertEquals 0 $?
	$BIN_DIR/service_control start $PrimaryWSID >/dev/null 2>/dev/null
	assertEquals 0 $?
	sleep 1
	`validate_stop_state_healthy_onboarded 2>/dev/null`
	assertEquals 1 $?
	`validate_stop_state_healthy_onboarded $PrimaryWSID 2>/dev/null`
	assertEquals 1 $?
	sleep 1
	
	return 0
}

test_validate_disable_state_healthy_onboarded() {
	
	$BIN_DIR/service_control disable $PrimaryWSID >/dev/null 2>/dev/null
	assertEquals 0 $?
	sleep 1
	validate_disable_state_healthy_onboarded >/dev/null 2>/dev/null
	assertEquals 0 $?
	validate_disable_state_healthy_onboarded $Primary_WSID >/dev/null 2>/dev/null
	assertEquals 0 $?
	$BIN_DIR/service_control start $PrimaryWSID >/dev/null 2>/dev/null
	assertEquals 0 $?
	sleep 1
	`validate_disable_state_healthy_onboarded 2>/dev/null`
	assertEquals 1 $?
	`validate_disable_state_healthy_onboarded $PrimaryWSID 2>/dev/null`
	assertEquals 1 $?
	sleep 1
	
	return 0
}

. shunit2

# End of test_oms_standard_validation_library.sh
