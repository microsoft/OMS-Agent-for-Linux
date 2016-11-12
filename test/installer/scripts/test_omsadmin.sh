BASE_DIR=$1
RUBY_TESTVERS=$2

if [ -z "$TEST_WORKSPACE_ID" -o -z "$TEST_SHARED_KEY" ];then
    echo "The environment variables TEST_WORKSPACE_ID and TEST_SHARED_KEY must be set for this test to run." 1>&2
    exit 1
fi

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

echo -n "Test Onboarding...  "
echo "======================== TEST ONBOARDING  ========================" > $DBG_ONDBOARD 

echo "bash -x $OMSADMIN -v -w $TEST_WORKSPACE_ID -s $TEST_SHARED_KEY" >> $DBG_ONDBOARD
bash -x $OMSADMIN -v -w $TEST_WORKSPACE_ID -s $TEST_SHARED_KEY >> $DBG_ONDBOARD 2>&1
handle_return_code $? $DBG_ONDBOARD

# Leave folder around if there was a failure for post mortem debug
if [ $HAS_FAILURE -eq 0 ]; then
    rm -rf $TESTDIR_SKEL*
else
    cat $TESTDIR/debug_*.fail 2>&1
fi

exit $HAS_FAILURE
