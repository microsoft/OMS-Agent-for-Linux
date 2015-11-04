BASE_DIR=$1
RUBY_TESTVERS=$2
chmod +x $BASE_DIR/test/installer/scripts/prep_omsadmin.sh
. $BASE_DIR/test/installer/scripts/prep_omsadmin.sh "$BASE_DIR" "$RUBY_TESTVERS"

HAS_FAILURE=0
handle_return_code()
{
    local ret_code=$1
    local dbg_file_path=$2
    if [ $ret_code -eq 0 ]; then
        echo "OK"
    else
        mv "$dbg_file_path" "$dbg_file_path.fail"
        echo "FAIL! Log stored in: $dbg_file_path.fail" 1>&2
        HAS_FAILURE=1
    fi
}

DBG_ONDBOARD=$TESTDIR/debug_onboarding
DBG_HEARTBEAT=$TESTDIR/debug_heartbeat
DBG_RENEWCERT=$TESTDIR/debug_renew_cert

echo -n "Test Onboarding...  "
echo "======================== TEST ONBOARDING  ========================" > $DBG_ONDBOARD 
# This is a static workspace ID and shared key that should not change
WORKSPACE_ID=PUT_IN_A_VALID_WORKSPACE_ID_FOR_THIS_TEST_TO_PASS
SHARED_KEY=PUT_IN_A_VALID_SHARED_KEY_FOR_THIS_TEST_TO_PASS

echo "bash -x $OMSADMIN -v -w $WORKSPACE_ID -s $SHARED_KEY" >> $DBG_ONDBOARD
bash -x $OMSADMIN -v -w $WORKSPACE_ID -s $SHARED_KEY >> $DBG_ONDBOARD 2>&1
handle_return_code $? $DBG_ONDBOARD

echo -n "Test Heartbeat...   "
echo "======================== TEST HEARTBEAT ========================" > $DBG_HEARTBEAT
echo "bash -x $OMSADMIN -v -b"  >> $DBG_HEARTBEAT
bash -x $OMSADMIN -v -b  >> $DBG_HEARTBEAT 2>&1
handle_return_code $? $DBG_HEARTBEAT

echo -n "Test Renew certs... "
echo "======================== TEST RENEW CERTS ========================" > $DBG_RENEWCERT
echo "bash -x $OMSADMIN -v -r" >> $DBG_RENEWCERT
bash -x $OMSADMIN -v -r  >> $DBG_RENEWCERT 2>&1
handle_return_code $? $DBG_RENEWCERT

# Leave folder around if there was a failure for post mortem debug
if [ $HAS_FAILURE -eq 0 ]; then
    rm -rf $TESTDIR_SKEL*
else
    cat $TESTDIR/debug_*.fail 2>&1
fi

exit $HAS_FAILURE
