#!/bin/bash

test -f /opt/omi/bin/omiserver && /opt/omi/bin/omiserver -v

#which rpm > /dev/null && rpm -q omi
#which dpkg > /dev/null && dpkg -l | grep omi