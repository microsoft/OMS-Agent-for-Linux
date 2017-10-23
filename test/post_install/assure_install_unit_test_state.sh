#! /bin/sh
# assure_install_unit_test_state.sh - Simply make sure at least a
# Primary workspace is in a running state.

$BIN_DIR/service_control is-running
# NOTE AGAIN:  this is-running feature uses programming language 1/0 true / false values
# instead of the 0/1 typical shellscript ones.
if [ $? -ne 1 ]
then
	echo "ERROR:  OMS agent is not in adequate working state for unit testing."
	echo "Please do manual tests to make sure at least a Primary agent is in a running state."
	exit 99
fi
#$BIN_DIR/omsadmin.sh -l
$BIN_DIR/omsadmin.sh -l | grep 'Primary Workspace: [^ ]' | sed 's/Primary Workspace: //' | sed 's/ *Status: *.*//'

# End of assure_install_unit_test_state.sh
