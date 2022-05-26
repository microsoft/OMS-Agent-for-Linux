#!/bin/bash

pkgName="scx-1.6.9-2.universal.x64.sh"
pkg="https://github.com/microsoft/SCXcore-kits/blob/partner/release/$pkgName?raw=true"

echo $pkg
wget -q $pkg -O /tmp/$pkgName
ls -l /tmp/$pkgName
echo sudo eval sh /tmp/$pkgName --upgrade
eval sudo sh /tmp/$pkgName --upgrade
/opt/microsoft/scx/bin/tools/scxadmin -v
