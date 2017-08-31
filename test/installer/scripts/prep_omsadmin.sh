BASE_DIR=$1
RUBY_TESTVERS=$2

TESTDIR_SKEL=/tmp/test_omsadmin_
TESTDIR=$TESTDIR_SKEL$$
mkdir -p $TESTDIR

echo "$TESTDIR"

OMSADMIN=$TESTDIR/omsadmin.sh
cp $BASE_DIR/installer/scripts/omsadmin.sh $OMSADMIN
chmod u+wx $OMSADMIN

TEST_USER=`id -un`
TEST_GROUP=`id -gn`

sed -i s,ETC_DIR=.*,ETC_DIR=$TESTDIR,1 $OMSADMIN
sed -i s,VAR_DIR=.*,VAR_DIR=$TESTDIR,1 $OMSADMIN
sed -i s,SYSCONF_DIR=.*,SYSCONF_DIR=$BASE_DIR/installer/conf,1 $OMSADMIN
sed -i s,OS_INFO=.*,OS_INFO=$TESTDIR/scx-release,1 $OMSADMIN
sed -i s,RUBY=.*,RUBY=${RUBY_TESTVERS}/bin/ruby,1 $OMSADMIN
sed -i s,AUTH_KEY_SCRIPT=.*,AUTH_KEY_SCRIPT=$BASE_DIR/installer/scripts/auth_key.rb,1 $OMSADMIN
sed -i s,TOPOLOGY_REQ_SCRIPT=.*,TOPOLOGY_REQ_SCRIPT=$BASE_DIR/source/code/plugins/agent_topology_request_script.rb,1 $OMSADMIN
sed -i s,MAINTENANCE_TASKS_SCRIPT=.*,MAINTENANCE_TASKS_SCRIPT=$BASE_DIR/source/code/plugins/agent_maintenance_script.rb,1 $OMSADMIN
sed -i s,INSTALL_INFO=.*,INSTALL_INFO=$BASE_DIR/installer/conf/installinfo.txt,1 $OMSADMIN
sed -i s,AGENT_USER=.*,AGENT_USER=$TEST_USER,1 $OMSADMIN
sed -i s,AGENT_GROUP=.*,AGENT_GROUP=$TEST_GROUP,1 $OMSADMIN
sed -i s,PROC_LIMIT_CONF=.*,PROC_LIMIT_CONF=$TESTDIR/limits.conf,1 $OMSADMIN

cat <<EOF > $TESTDIR/process_stats
    PercentUserTime=2
    PercentPrivilegedTime=1
    UsedMemory=27712
    PercentUsedMemory=3
EOF

cat <<EOF > $TESTDIR/scx-release
OSName=Ubuntu
OSVersion=14.04
OSFullName=Ubuntu 14.04 (x86_64)
OSAlias=UniversalD
OSManufacturer=Canonical Group Limited
OSShortName=Ubuntu_14.04
EOF

cat <<EOF > $TESTDIR/limits.conf
@$TEST_GROUP          hard           nproc                20
*       hard    nproc   10
omiagent    soft    nproc 75
#        hard    nproc           75
$TEST_USER soft nproc 200
#    $TEST_USER hard nproc 20000
EOF

cat <<EOF > $TESTDIR/limits-default.conf
@$TEST_GROUP          hard           nproc                20
*       hard    nproc   10
omiagent    soft    nproc 75
#        hard    nproc           75
$TEST_USER  hard  nproc  75
#    $TEST_USER hard nproc 20000
EOF

cat <<EOF > $TESTDIR/limits-non-default.conf
@$TEST_GROUP          hard           nproc                20
*       hard    nproc   10
omiagent    soft    nproc 75
#        hard    nproc           75
$TEST_USER  hard  nproc  5000
#    $TEST_USER hard nproc 20000
EOF

cat <<EOF > $TESTDIR/limits-two-settings.conf
@$TEST_GROUP          hard           nproc                20
*       hard    nproc   10
omiagent    soft    nproc 75
#        hard    nproc           75
$TEST_USER  hard  nproc  200
$TEST_USER  hard  nproc  100
#    $TEST_USER hard nproc 20000
EOF

cat <<EOF > $TESTDIR/limits-no-settings.conf
@$TEST_GROUP          hard           nproc                20
*       hard    nproc   10
omiagent    soft    nproc 75
#        hard    nproc           75
#    $TEST_USER hard nproc 20000
EOF

# The following two represent the actual kind of file ending found on systems:
cat <<EOF > $TESTDIR/limits-no-settings-endlabel.conf
@$TEST_GROUP          hard           nproc                20
*       hard    nproc   10
omiagent    soft    nproc 75
#        hard    nproc           75
#    $TEST_USER hard nproc 20000

# End of file
EOF

cat <<EOF > $TESTDIR/limits-new-settings-endlabel.conf
@$TEST_GROUP          hard           nproc                20
*       hard    nproc   10
omiagent    soft    nproc 75
#        hard    nproc           75
#    $TEST_USER hard nproc 20000
$TEST_USER  hard  nproc  20000

# End of file
EOF
