BASE_DIR=$1
RUBY_TESTVERS=$2

TESTDIR_SKEL=/tmp/test_omsadmin_
TESTDIR=$TESTDIR_SKEL$$
mkdir -p $TESTDIR

DBG_ONDBOARD=$TESTDIR/debug_onboarding
DBG_HEARTBEAT=$TESTDIR/debug_heartbeat
DBG_RENEWCERT=$TESTDIR/debug_renew_cert

OMSADMIN=$TESTDIR/omsadmin.sh
cp $BASE_DIR/installer/scripts/omsadmin.sh $OMSADMIN
chmod u+wx $OMSADMIN

sed -i s,TMP_DIR=.*,TMP_DIR=$TESTDIR,1 $OMSADMIN
sed -i s,CONF_DIR=.*,CONF_DIR=$TESTDIR,1 $OMSADMIN
sed -i s,CERT_DIR=.*,CERT_DIR=$TESTDIR,1 $OMSADMIN
sed -i s,OS_INFO=.*,OS_INFO=$TESTDIR/scx-release,1 $OMSADMIN
sed -i s,RUBY=.*,RUBY=${RUBY_TESTVERS}/bin/ruby,1 $OMSADMIN
sed -i s,AUTH_KEY_SCRIPT=.*,AUTH_KEY_SCRIPT=$BASE_DIR/installer/scripts/auth_key.rb,1 $OMSADMIN
sed -i s,INSTALL_INFO=.*,INSTALL_INFO=$BASE_DIR/installer/conf/installinfo.txt,1 $OMSADMIN

echo endpoint_url=https://WORKSPACE_ID.ods.opinsights.azure.com/OperationalData.svc/PostJsonDataItems.com > $TESTDIR/omsagent.conf

cat <<EOF > $TESTDIR/scx-release
OSName=Ubuntu
OSVersion=14.04
OSFullName=Ubuntu 14.04 (x86_64)
OSAlias=UniversalD
OSManufacturer=Canonical Group Limited
EOF


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

echo -n "Test Onboarding...  "
echo "======================== TEST ONBOARDING  ========================" > $DBG_ONDBOARD 
# This is a static workspace ID and shared key that should not change
WORKSPACE_ID=cec9ea66-f775-41cd-a0a6-2d0f0ffdac6f
SHARED_KEY=qoTgVB0a1393p4FUncrY0nc/U1/CkOYlXz3ok3Oe79gSB6NLa853hiQzcwcyBb10Rjj7iswRvoJGtLJUD/o/yw==

echo "sudo bash -x $OMSADMIN -v -w $WORKSPACE_ID -s $SHARED_KEY" >> $DBG_ONDBOARD
sudo bash -x $OMSADMIN -v -w $WORKSPACE_ID -s $SHARED_KEY >> $DBG_ONDBOARD 2>&1
handle_return_code $? $DBG_ONDBOARD

echo -n "Test Heartbeat...   "
echo "======================== TEST HEARTBEAT ========================" > $DBG_HEARTBEAT
echo "sudo bash -x $OMSADMIN -v -b"  >> $DBG_HEARTBEAT
sudo bash -x $OMSADMIN -v -b  >> $DBG_HEARTBEAT 2>&1
handle_return_code $? $DBG_HEARTBEAT

echo -n "Test Renew certs... "
echo "======================== TEST RENEW CERTS ========================" > $DBG_RENEWCERT
echo "bash -x $OMSADMIN -v -r" >> $DBG_RENEWCERT
sudo bash -x $OMSADMIN -v -r  >> $DBG_RENEWCERT 2>&1
handle_return_code $? $DBG_RENEWCERT

# Leave folder around if there was a failure for post mortem debug
if [ $HAS_FAILURE -eq 0 ]; then
    rm -rf $TESTDIR_SKEL*
else
    cat $TESTDIR/debug_*.fail 2>&1
fi

exit $HAS_FAILURE
