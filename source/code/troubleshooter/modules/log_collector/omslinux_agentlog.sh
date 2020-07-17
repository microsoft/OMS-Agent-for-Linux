#! /bin/sh

#   OMS Log Collector to collect logs and command line outputs for
#   troubleshooting OMS Linux Agent (Github, Extension & Container)
#   issues by support personnel
#
#   Authors, Reviewers & Contributors : 
#                 KR Kandavel Azure CAT PM
#                 Keiko Harada OMS PM,
#                 Laura Galbraith OMS SE
#                 Jim Britt Azure CAT PM
#                 Gary Keong OMS Eng. Mgr
#                 Adrian Doyle CSS PM
#   Date        : 2017-06-16
#   Version     : 1.0

PATH=/usr/bin:/usr/sbin:/bin:/sbin
umask 022

OMS_LOGCOLLECTOR=omslinux_agentlog.py
PYTHON=""

# Can't use something like 'readlink -e $0' because that doesn't work everywhere
# And HP doesn't define $PWD in a sudo environment, so we define our own
case $0 in
    /*|~*)
        SCRIPT_INDIRECT="`dirname $0`"
        ;;
    *)
        PWD="`pwd`"
        SCRIPT_INDIRECT="`dirname $PWD/$0`"
        ;;
esac
echo $SCRIPT_INDIRECT

# Displays the Usage options for command 
# if the given input option is invalid
usage()
{
   echo "Usage: sudo $1 [OPTIONS]"
   echo "Options:"
   echo "  -s srnum, --srnum srnum         Use SR Number to collect OMS Logs"
   echo "  -c comname, --comname comname   Company name for reference <Optional>"
   echo "  -? | -h | --help                Shows this usage text."
}

# Checks if python is installed and required
# python modules can be imported successfully 
python_prereqchk()
{
    # Check for Python ctypes library (required for omsconfig)
    prereqpass=0
    echo "Checking for python install ..."
    which python2 1> /dev/null 2> /dev/null
    if [ $? -eq 0 ]; then
        PYTHON="python2"
        echo "Using $PYTHON"
    else
        which python3 1> /dev/null 2> /dev/null
        if [ $? -eq 0 ]; then
            PYTHON="python3"
            echo "Using $PYTHON"
        else
            "No python2 or python3 executable found"
            prereqpass=1
            return $prereqpass
        fi
    fi

    echo "Checking for required python modules ..."
    $PYTHON -c "import ctypes" 1> /dev/null 2> /dev/null
    [ $? -ne 0 ] && prereqpass=1

    $PYTHON -c "import os" 1> /dev/null 2> /dev/null
    [ $? -ne 0 ] && prereqpass=1

    $PYTHON -c "import subprocess" 1> /dev/null 2> /dev/null
    [ $? -ne 0 ] && prereqpass=1

    $PYTHON -c "import logging" 1> /dev/null 2> /dev/null
    [ $? -ne 0 ] && prereqpass=1

    $PYTHON -c "import sys" 1> /dev/null 2> /dev/null
    [ $? -ne 0 ] && prereqpass=1

    $PYTHON -c "import getopt" 1> /dev/null 2> /dev/null
    [ $? -ne 0 ] && prereqpass=1

    $PYTHON -c "import datetime" 1> /dev/null 2> /dev/null
    [ $? -ne 0 ] && prereqpass=1

    return $prereqpass
}

# Checks if OMS Linux Agent install directory is present 
# if not then it recommends running the OMS Linux Agent
# installation before collecting logs for troubleshooting
oms_prereqchk()
{
    echo "Checking for OMS Linux Agent install..." 
    omsprereqflag=0
    if [ ! -d /var/opt/microsoft/omsagent ] && [ ! -d /var/opt/microsoft/omsconfig ]; then
        echo "OMS Linux Agent install directories are not present
        > please run OMS Linux Agent install script
        > For details on installing OMS Agent, please refer documentation
        > https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-agent-linux"
        omsprereqflag=1
    fi
    return $omsprereqflag
}

# Main logic to check pre-requisites &
# run python script to collect logs
argchk=1
while [ $# -ne 0 ] && [ $argchk -ne 0 ]
do
    case "$1" in
         -s | --srnum)
            argchk=0
            ;;
         -/? | -h | --help)
            usage `basename $0` >&2
            exit 0
            ;;
         *)
            echo "Unknown argument: '$1'" >&2
            echo "Use -h or --help for usage" >&2
            exit 1
            ;;
    esac
done

python_prereqchk
if [ $? -ne 0 ]; then
     echo "Required OMS prerequisite python executable and python modules not installed ..."
     exit 1
fi

#oms_prereqchk
#if [ $? -ne 0 ]; then
#     echo "OMS Linux Agent not installed for collecting OMS Logs..."
#     exit 1
#fi

echo "Calling Python script to collect OMS Logs...<START> $3"
if [ -n $3 ] && [ "$3" = "-c" ]; then
     echo $3
     echo $4
     sudo $PYTHON $SCRIPT_INDIRECT/$OMS_LOGCOLLECTOR -s "$2" -c "$4"
else
     sudo $PYTHON $SCRIPT_INDIRECT/$OMS_LOGCOLLECTOR -s "$2"
fi
echo "Calling Python script to collect OMS Logs...<END>"

exit 0
