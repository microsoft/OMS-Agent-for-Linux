#!/bin/bash
#
#
# This script will create a bundle file given an existing kit.
#
# See usage for parameters that must be passed to this script.
#
# We expect this script to run from the BUILD directory (i.e. oms/build).
# Directory paths are hard-coded for this location.

SOURCE_DIR=`(cd ../installer/bundle; pwd -P)`
BUNDLE_FILE=bundle_skel.sh

# Exit on error
set -e

# Don't display output
set +x

usage()
{
    echo "usage: $0 directory tar-file"
    echo "  where"
    echo "    directory is directory path to package file (target directory)"
    echo "    tar-file is the name of the tar file that contains the .deb/.rpm files"
    echo
    echo "This script, and the associated bundle skeleton, are intended to work only"
    echo "only on Linux, and only for universal installations. As such, package names"
    echo "are determined via directory lookups."
    echo
    echo "Note that the \"directory\" parameter must contain both \"098\" and \"100\""
    echo "directories (for SSL 0.9.8 and SSL 1.0.0), so that we have .rpm and .deb"
    echo "files for each of the SSL-sensitive files."
    exit 1
}

# Validate parameters

DIRECTORY=$1
TAR_FILE=$2

if [ -z "$DIRECTORY" ]; then
    echo "Missing parameter: Target Directory" >&2
    echo ""
    usage
    exit 1
fi

if [ ! -d "$DIRECTORY" ]; then
    echo "Directory \"$DIRECTORY\" does not exist" >&2
    exit 1
fi

if [ -z "$TAR_FILE" ]; then
    echo "Missing parameter: tar-file" >&2
    echo ""
    usage
    exit 1
fi

if [ ! -f "$DIRECTORY/$TAR_FILE" ]; then
    echo "Can't file tar file at location $DIRECTORY/$TAR_FILE" >&2
    echo ""
    usage
    exit 1
fi

INTERMEDIATE_DIR=`(cd $DIRECTORY/installer_tmp; pwd -P)`

# Switch to one of the output directories to avoid directory prefixes
cd $DIRECTORY/098

SCX_PACKAGE=`ls scx-*.rpm | sed 's/.rpm$//'`
OMI_PACKAGE=`ls omi-*.rpm | sed 's/.rpm$//'`
OMS_PACKAGE=`ls omsagent-*.rpm | sed 's/.rpm$//'`

# TODO : Add verification to insure all flavors exist

# Determine the output file name
OUTPUT_DIR=`(cd $DIRECTORY; pwd -P)`

# Work from the temporary directory from this point forward
cd $INTERMEDIATE_DIR

# Fetch the bundle skeleton file
cp $SOURCE_DIR/$BUNDLE_FILE .
chmod u+w $BUNDLE_FILE

# Edit the bundle file for hard-coded values
sed -i "s/TAR_FILE=<TAR_FILE>/TAR_FILE=$TAR_FILE/" $BUNDLE_FILE

sed -i "s/OMI_PKG=<OMI_PKG>/OMI_PKG=$OMI_PACKAGE/" $BUNDLE_FILE
sed -i "s/OMS_PKG=<OMS_PKG>/OMS_PKG=$OMS_PACKAGE/" $BUNDLE_FILE
sed -i "s/SCX_PKG=<SCX_PKG>/SCX_PKG=$SCX_PACKAGE/" $BUNDLE_FILE

SCRIPT_LEN=`wc -l < $BUNDLE_FILE | sed 's/ //g'`
SCRIPT_LEN_PLUS_ONE="$((SCRIPT_LEN + 1))"

sed -i "s/SCRIPT_LEN=<SCRIPT_LEN>/SCRIPT_LEN=${SCRIPT_LEN}/" $BUNDLE_FILE
sed -i "s/SCRIPT_LEN_PLUS_ONE=<SCRIPT_LEN+1>/SCRIPT_LEN_PLUS_ONE=${SCRIPT_LEN_PLUS_ONE}/" $BUNDLE_FILE

# Build the bundle
BUNDLE_OUTFILE=$OUTPUT_DIR/`echo $TAR_FILE | sed -e "s/.tar//"`.sh
echo "Generating bundle in target named: `basename $BUNDLE_OUTFILE` ..."

gzip -c $OUTPUT_DIR/$TAR_FILE | cat $BUNDLE_FILE - > $BUNDLE_OUTFILE
chmod +x $BUNDLE_OUTFILE

# Clean up
rm $BUNDLE_FILE

exit 0
