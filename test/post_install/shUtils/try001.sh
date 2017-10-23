#!/bin/sh

THISSCRIPT=$0
. ./shUtils.sh

$AreShellArgumentsAvailable
echo "trace 0 $?"
echo $AreShellArgumentsAvailable

echo "trace 1 $*"
echo "trace 2 $@"
