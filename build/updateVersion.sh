#! /bin/bash
#
# Update the version file each day for the daily build
#

VERSION_FILE=Makefile.version

if [ ! -f $VERSION_FILE ]; then
    echo "Can't find file Makefile.version" 1>& 2
    exit 1
fi

if [ ! -w $VERSION_FILE ]; then
    echo "File Makefile.version is not writeable" 1>& 2
    exit 1
fi

# Parsing logic

usage()
{
    echo "$0 <options>"
    echo
    echo "Valid options are:"
    echo "  -h:  This message"
    echo "  -i:  Increment build number and set date"
    echo "  -r:  Set for release build"
    echo "  -v:  Verbose output"
    echo
    echo "With no options at all, -i is assumed"

    exit 1
}

P_INCREMENT=0
P_RELEASE=0
VERBOSE=0

while getopts "h?irv" opt; do
    case "$opt" in
        h|\?)
            usage
            ;;
        i)
            P_INCREMENT=1
            ;;
        r)
            P_RELEASE=1
            ;;
        v)
            VERBOSE=1
            ;;
    esac
done
shift $((OPTIND-1))

if [ "$@ " != " " ]; then
    echo "Parsing error: '$@' is unparsed, use -h for help" 1>& 2
    exit 1
fi

# Set default behavior
[ $P_RELEASE -eq 0 ] && P_INCREMENT=1

. Makefile.version

# Increment build number
if [ $P_INCREMENT -ne 0 ]; then
    VERSION_OLD=$OMS_BUILDVERSION_BUILDNR
    DATE_OLD=$OMS_BUILDVERSION_DATE

    VERSION_NEW=$(( $VERSION_OLD + 1 ))
    DATE_NEW=`date +%Y%m%d`

    sed -i "s/OMS_BUILDVERSION_BUILDNR=.*/OMS_BUILDVERSION_BUILDNR=$VERSION_NEW/" $VERSION_FILE
    sed -i "s/OMS_BUILDVERSION_DATE=.*/OMS_BUILDVERSION_DATE=$DATE_NEW/" $VERSION_FILE

    if [ $VERBOSE -ne 0 ]; then
        echo "Updated version number, Was: $VERSION_OLD, Now $VERSION_NEW"
        echo "Updated release date,   Was: $DATE_OLD, Now $DATE_NEW"
    fi
fi

# Set release build
if [ $P_RELEASE -ne 0 ]; then
    sed -i "s/OMS_BUILDVERSION_STATUS=.*/OMS_BUILDVERSION_STATUS=Release_Build/" $VERSION_FILE
    [ $VERBOSE -ne 0 ] && echo "Set BUILDVERSION_STATUS to \"Release_Build\""
    echo "WARNING: Never commit $VERSION_FILE with release build set!" 1>& 2
fi

exit 0
