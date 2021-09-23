#!/bin/bash

test -f /opt/omi/bin/omiserver && /opt/omi/bin/omiserver -v

which rpm > /dev/null && rpm -qa | grep -E 'omi|omsagent|lad'
which dpkg > /dev/null && dpkg -l | grep -E 'omi|omsagent|lad'