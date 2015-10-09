set -e

BASE_DIR=$1
TESTDIR=/tmp/test_omsadmin_$$
mkdir -p $TESTDIR

OMSADMIN=$TESTDIR/omsadmin.sh

cp $BASE_DIR/installer/scripts/omsadmin.sh $OMSADMIN
chmod u+wx $OMSADMIN

sed -i s,TMP_DIR=.*,TMP_DIR=$TESTDIR,1 $OMSADMIN
sed -i s,CONF_DIR=.*,CONF_DIR=$TESTDIR,1 $OMSADMIN
sed -i s,CERT_DIR=.*,CERT_DIR=$TESTDIR,1 $OMSADMIN
sed -i s,OS_INFO=.*,OS_INFO=$TESTDIR/scx-release,1 $OMSADMIN

echo endpoint_url=https://WORKSPACE_ID.ods.opinsights.azure.com/OperationalData.svc/PostJsonDataItems.com > $TESTDIR/omsagent.conf

cat <<EOF > $TESTDIR/scx-release
OSName=Ubuntu
OSVersion=14.04
OSFullName=Ubuntu 14.04 (x86_64)
OSAlias=UniversalD
OSManufacturer=Canonical Group Limited
EOF

# This is a static workspace ID and shared key that should not change
echo ============= Test Onboarding:
sudo $OMSADMIN -w cec9ea66-f775-41cd-a0a6-2d0f0ffdac6f -s qoTgVB0a1393p4FUncrY0nc/U1/CkOYlXz3ok3Oe79gSB6NLa853hiQzcwcyBb10Rjj7iswRvoJGtLJUD/o/yw==

echo ============= Test Heartbeat:
sudo $OMSADMIN -b

echo ============= Test Renew certs:
sudo $OMSADMIN -r

rm -rf $TESTDIR
exit 0
