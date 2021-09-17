#!/bin/bash

osslverstr=$(openssl version)
echo $osslverstr
echo $osslverstr | grep 1.1. > /dev/null
isSSL11=$?
echo isSSL11=$isSSL11
echo $osslverstr | grep 1.0. > /dev/null
isSSL10=$?
echo isSSL10=$isSSL10

if [ $isSSL11 = 0 ]; then
    osslver="110"
elif [ $isSSL10 = 0 ]; then
    osslver="100"
else
    echo "Unexpected Open SSL version"
    exit -1
fi

which dpkg > /dev/null
if [ $? = 0 ]; then
    pkgMgr="dpkg -i"
    pkgName="omi-1.6.8-1.ssl_${osslver}.ulinux.x64.deb"
else
    which rpm > /dev/null
    if [ $? = 0 ]; then
        # sometimes rpm db is not in a good shape.
        pkgMgr="rpm --rebuilddb && rpm -Uhv"
        #pkgMgr="rpm -Uhv"
        pkgName="omi-1.6.8-1.ssl_${osslver}.ulinux.x64.rpm"
    else
        echo Unknown package manager
        exit -2
    fi
fi

pkg="https://github.com/microsoft/omi/releases/download/v1.6.8-1/$pkgName"
echo $pkg
wget -q $pkg -O /tmp/$pkgName
ls -l /tmp/$pkgName
echo sudo eval $pkgMgr /tmp/$pkgName
eval sudo $pkgMgr /tmp/$pkgName
/opt/omi/bin/omiserver -v
