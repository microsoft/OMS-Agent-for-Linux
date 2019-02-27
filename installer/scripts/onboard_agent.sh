#!/bin/sh

#
# Easy download/install/onboard script for the OMSAgent for Linux
#


# Values to be updated upon each new release
GITHUB_RELEASE="https://github.com/Microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent_v1.9.0-0/"
BUNDLE_X64="omsagent-1.9.0-0.universal.x64.sh"
BUNDLE_X86="omsagent-1.9.0-0.universal.x86.sh"

usage()
{
    echo "usage: $1 [OPTIONS]"
    echo "Options:"
    echo "  -w id, --id id             Use workspace ID <id> for automatic onboarding."
    echo "  -s key, --shared key       Use <key> as the shared key for automatic onboarding."
    echo "  -d dmn, --domain dmn       Use <dmn> as the OMS domain for onboarding. Optional."
    echo "                             default: opinsights.azure.com"
    echo "                             ex: opinsights.azure.us (for FairFax)"
    echo "  -p conf, --proxy conf      Use <conf> as the proxy configuration."
    echo "                             ex: -p [protocol://][user:password@]proxyhost[:port]"
    echo "  --purge                    Uninstall the package and remove all related data."
    echo "  -? | -h | --help           shows this usage text."
}


# Extract parameters
while [ $# -ne 0 ]
do
    case "$1" in
        -d|--domain)
            topLevelDomain=$2
            shift 2
            ;;

        -s|--shared)
            onboardKey=$2
            shift 2
            ;;

        -w|--id)
            onboardID=$2
            shift 2
            ;;

        --purge)
            purgeAgent="true"
            break;
            ;;

        -p|--proxy)
            proxyConf=$2
            shift 2
            ;;

        -\? | -h | --help)
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


# Assemble parameters
bundleParameters="--upgrade"
if [ -n "$onboardID" ]; then
    bundleParameters="${bundleParameters} -w $onboardID"
fi
if [ -n "$onboardKey" ]; then
    bundleParameters="${bundleParameters} -s $onboardKey"
fi
if [ -n "$topLevelDomain" ]; then
    bundleParameters="${bundleParameters} -d $topLevelDomain"
fi
if [ -n "$purgeAgent" ]; then
    bundleParameters="--purge"
fi
if [ -n "$proxyConf" ]; then
    bundleParameters="${bundleParameters} -p $proxyConf"
fi

# We need to use sudo for commands in the following block, if not running as root
SUDO=''
if (( $EUID != 0 )); then
    SUDO='sudo'
fi

# Download, install, and onboard OMSAgent for Linux, depending on architecture of machine
if [ $(uname -m) = 'x86_64' ]; then
    # x64 architecture
    wget -O ${BUNDLE_X64} ${GITHUB_RELEASE}${BUNDLE_X64} && $SUDO sh ./${BUNDLE_X64} ${bundleParameters}
else
    # x86 architecture
    wget -O ${BUNDLE_X86} ${GITHUB_RELEASE}${BUNDLE_X86} && $SUDO sh ./${BUNDLE_X86} ${bundleParameters}
fi
