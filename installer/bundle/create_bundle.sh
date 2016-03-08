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
    echo "usage: $0 target-dir intermediate-dir tar-file"
    echo "  where"
    echo "    target-dir is directory path to create shell bundle file (target directory)"
    echo "    intermediate-dir is dir path to intermediate dir (where installer_tmp lives)"
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
INTERMEDIATE=$2
TAR_FILE=$3

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

if [ -z "$INTERMEDIATE" ]; then
    echo "Missing parameter: Intermediate Directory" >&2
    echo ""
    usage
    exit 1
fi

if [ ! -d "$INTERMEDIATE" ]; then
    echo "Directory \"$INTERMEDIATE\" does not exist" >&2
    exit 1
fi

if [ ! -d "$INTERMEDIATE/installer_tmp" ]; then
    echo "Directory \"$INTERMEDIATE/installer_tmp\" does not exist" >&2
    exit 1
fi

if [ -z "$TAR_FILE" ]; then
    echo "Missing parameter: tar-file" >&2
    echo ""
    usage
    exit 1
fi

if [ ! -f "$INTERMEDIATE/$TAR_FILE" ]; then
    echo "Can't file tar file at location $INTERMEDIATE/$TAR_FILE" >&2
    echo ""
    usage
    exit 1
fi

INTERMEDIATE_DIR=`(cd $INTERMEDIATE; pwd -P)`

# Switch to one of the output directories to avoid directory prefixes
cd $INTERMEDIATE/098

SCX_PACKAGE=`ls scx-*.rpm | sed 's/.rpm$//' | tail -1`
OMI_PACKAGE=`ls omi-*.rpm | sed 's/.rpm$//' | tail -1`
OMS_PACKAGE=`ls omsagent-*.rpm | sed 's/.rpm$//' | tail -1`
DSC_PACKAGE=`ls omsconfig-*.rpm | sed 's/.rpm$//' | tail -1`

# TODO : Add verification to insure all flavors exist

# Determine the output file name
OUTPUT_DIR=`(cd $DIRECTORY; pwd -P)`

# Work from the temporary directory from this point forward
cd $INTERMEDIATE_DIR

# Fetch the bundle skeleton file
cp $SOURCE_DIR/$BUNDLE_FILE .

# See if we can resolve git references for output
# (See if we can find the master project)
if [ -f ../../../.gitmodules ]; then
    TEMP_FILE=/tmp/create_bundle.$$

    # Get the git reference hashes in a file
    (
	cd ../../..
	echo "Entering 'superproject'" > $TEMP_FILE
	git rev-parse HEAD >> $TEMP_FILE
	git submodule foreach git rev-parse HEAD >> $TEMP_FILE
    )

    # Change lines like: "Entering 'dsc'\n<refhash>" to "dsc: <refhash>"
    perl -i -pe "s/Entering '([^\n]*)'\n/\$1: /" $TEMP_FILE

    # Grab the reference hashes in a variable
    SOURCE_REFS=`cat $TEMP_FILE`
    rm $TEMP_FILE

    # Update the bundle file w/the ref hash (much easier with perl since multi-line)
    perl -i -pe "s/-- Source code references --/${SOURCE_REFS}/" $BUNDLE_FILE
else
    echo "Unable to find git superproject!" >& 2
    exit 1
fi

# Edit the bundle file for hard-coded values
sed -i "s/TAR_FILE=<TAR_FILE>/TAR_FILE=$TAR_FILE/" $BUNDLE_FILE

sed -i "s/OMI_PKG=<OMI_PKG>/OMI_PKG=$OMI_PACKAGE/" $BUNDLE_FILE
sed -i "s/OMS_PKG=<OMS_PKG>/OMS_PKG=$OMS_PACKAGE/" $BUNDLE_FILE
sed -i "s/DSC_PKG=<DSC_PKG>/DSC_PKG=$DSC_PACKAGE/" $BUNDLE_FILE
sed -i "s/SCX_PKG=<SCX_PKG>/SCX_PKG=$SCX_PACKAGE/" $BUNDLE_FILE

SCRIPT_LEN=`wc -l < $BUNDLE_FILE | sed 's/ //g'`
SCRIPT_LEN_PLUS_ONE="$((SCRIPT_LEN + 1))"

sed -i "s/SCRIPT_LEN=<SCRIPT_LEN>/SCRIPT_LEN=${SCRIPT_LEN}/" $BUNDLE_FILE
sed -i "s/SCRIPT_LEN_PLUS_ONE=<SCRIPT_LEN+1>/SCRIPT_LEN_PLUS_ONE=${SCRIPT_LEN_PLUS_ONE}/" $BUNDLE_FILE

# Build the bundle
BUNDLE_OUTFILE=$OUTPUT_DIR/`echo $TAR_FILE | sed -e "s/.tar//"`.sh
echo "Generating bundle in target named: `basename $BUNDLE_OUTFILE` ..."

gzip -c $INTERMEDIATE/$TAR_FILE | cat $BUNDLE_FILE - > $BUNDLE_OUTFILE
chmod +x $BUNDLE_OUTFILE

# Clean up
rm $BUNDLE_FILE

exit 0
