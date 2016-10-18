#!/bin/bash

# Script to sign DSC modules from a Linux box and drop off signed packages (in zip format) into build share.
# It merges x86 and x 84 DSC modules, then generates a checksum file for it, uploads to azure storage account using SAS URI.
# Once the checksume file is signed as *.asc file, it downloads and 
# serializes the signed file into the zip package for given module.
# Script assumes that source and destination containers are created in azure storage account with proper write and read permissions
# 
# Supported parameters
# $1 - SAS URI of source container which contains the file to be signed
# $2 - SAS URI of destination container where the signed file is dropped
# $3 - Build version. Example 1.2.0-118
# $4 - Build share location to download given build . Example /mnt/omsdata/OMSData/Builds/omsagent/develop

# If no arguments, print usage statement & exit from function
[ $# -eq 0 ] && { echo "Usage: $0 <sas_source_uri> <sas_destination_uri> <build_version> <build_share_location>"; exit 1; }

StorageVersion="2014-02-14"
# Max number of attempts to wait for signing worklow to finish 
MaxSignWaitAttempts=30

# read_blob <URI> <REMOTE_FILE> <DEST_FILE>
read_blob() {

    [ ! -z "$1" ] || error "read_blob(): expected remote URI" 1
    [ ! -z "$2" ] || error "read_blob(): expected remote filename" 1
    [ ! -z "$3" ] || error "read_blob(): expected destination file" 1

    url="$1"
    remotefile="$2"
    localfile="$3"

    container=$( echo "$1" | awk -F \?  '{container=index($0,"?"); print $1}' )
	sas=$( echo "$url" | awk -F \? '{container=index($0,"?"); print $2}' )
    url="${container}/${remotefile}?${sas}"

    timestamp=$(date +%Y-%m-%dT%H:%M:%SZ)
    output=$(curl --silent --write-out %{http_code} --request "GET" \
                  --header "x-ms-date    : $timestamp" \
                  --header "x-ms-version : $StorageVersion" \
                  "$url" )
    
    code=${output: (-3)}	
	if [ "$code" != 200 ]; then
	    echo "read_blob(): error retrieving $remotefile from container $container, server returned an http error code $code"
        return 1
    fi

    output=${output: :(-3)}
    echo -n "$output" > "$localfile"
   
    return 0
}

# write_blob <SASURL> <FILE>
write_blob() {

    [ ! -z "$1" ] || error "write_blob(): expected remote URI" 1
    [ ! -z "$2" ] || error "write_blob(): expected filename to upload" 1
    [ -f "$2" ] || error "write_blob(): file $2 does not exist" 1

    url="$1"
    localfile="$2"
    remotefile=$(basename "$localfile")

    container=$( echo "$1" | awk -F \?  '{container=index($0,"?"); print $1}' )
    sas=$( echo "$url" | awk -F \? '{container=index($0,"?"); print $2}' )
    url="${container}/${remotefile}?${sas}"

    timestamp=$(date +%Y-%m-%dT%H:%M:%SZ)
    output=$(curl --silent --write-out %{http_code} --request "PUT" \
                  --header "x-ms-date      : $timestamp" \
                  --header "x-ms-blob-type : BlockBlob" \
                  --header "x-ms-version   : $StorageVersion" \
                  --data-binary "@${localfile}" "$url" )
    
    code=${output: (-3)}
	if [ "$code" != 201 ]; then
        echo "write_blob(): error writing $remotefile into container $container, server returned an http error code $code"
		return 1
    fi

    return 0
}

# delete <URI> <REMOTE_FILE>
delete_blob() {

    [ ! -z "$1" ] || error "delete_blob(): expected remote URI" 1
    [ ! -z "$2" ] || error "delete_blob(): expected remote filename" 1
   
    url="$1"
    remotefile="$2"
    
    container=$( echo "$1" | awk -F \?  '{container=index($0,"?"); print $1}' )
    sas=$( echo "$url" | awk -F \? '{container=index($0,"?"); print $2}' )
    url="${container}/${remotefile}?${sas}"
    echo "url is $url"
    timestamp=$(date +%Y-%m-%dT%H:%M:%SZ)
    output=$(curl --silent --write-out %{http_code} --request "DELETE" \
                  --header "x-ms-date    : $timestamp" \
                  --header "x-ms-version : $StorageVersion" \
                  "$url" )
    
    code=${output: (-3)}
    if [[ "$code" != 202 ]]  && [[ "$code" != 404 ]]; then
        echo "delete_blob(): error deleting $remotefile from container $container, server returned error code $code"
		return 1
    fi    
    return 0
}
# SAS URLs
SAS_SOURCE_URI=$1
echo " SAS source container URL is : $1"
SAS_DEST_URI=$2
echo " SAS destination container URL is : $2"
# Build info
BUILD_VERS=$3
BUILD_BASEDIR=$4

if [ "$BUILD_BASEDIR" = "" ]; then
    echo "No build share path is specified. Default build share is mounted at: /mnt/omsdata"
    BUILD_BASEDIR=/mnt/omsdata/OMSData/Builds/omsagent/develop
else
    echo "Build share is mounted at: $4"
fi

if [ ! -d $BUILD_BASEDIR ]; then
    echo "Not finding Build share mounted at $BUILD_BASEDIR ..."
    exit 1
fi

if [ "$BUILD_VERS" = "" ]; then
    echo "No build version is specified."
    exit 1
else
    echo "Build version: $3"
fi

BUILD_BASEDIR=${BUILD_BASEDIR}/${BUILD_VERS}

if [ ! -d $BUILD_BASEDIR ]; then
    echo "No build version $BUILD_VERS was found at oms build share: $BUILD_BASEDIR"
    exit 1
fi

if ! zip -L 1>/dev/null; then
    echo "zip must be installed"
    exit 1
fi

if ! unzip -Z 1>/dev/null; then
    echo "unzip must be installed"
    exit 1
fi

# Working directory used for merging both x64 and x86 versions of a DSC module.
DscModuleIntermediateDir="/tmp/merging_dsc_modules"

# Working directory where the signed package is dropped.
DscModuleTargetDir="/tmp/dsc_signed"

# Locations of dsc modules that need to be signed
X64Dir="$BUILD_BASEDIR/Linux_ULINUX_1.0_x64_64_Release/dsc"
X86Dir="$BUILD_BASEDIR/Linux_ULINUX_1.0_x86_32_Release/dsc"

set -e

if [ -d "$DscModuleIntermediateDir" ]; then
    rm -rf "$DscModuleIntermediateDir"
fi

mkdir -p "$DscModuleIntermediateDir"

for ModuleFilePath in $X64Dir/*.zip;
do
    # expected file name: nxOMSPlugin_1.0.zip
    ModuleFileName=`basename $ModuleFilePath`
    ModuleName=`echo $ModuleFileName | cut -d _ -f 1`
    
    if [ -f "$X64Dir/$ModuleFileName" ]
    then
        echo "Found x64 module .zip: "$X64Dir/$ModuleFileName""
    else
        echo "Did not find x64 module .zip: "$X64Dir/$ModuleFileName""
        exit 1
    fi

    if [ -f "$X86Dir/$ModuleFileName" ]
    then
        echo "Found x86 module .zip: "$X86Dir/$ModuleFileName""
    else
        echo "Did not find x86 module .zip: "$X86Dir/$ModuleFileName""
        exit 1
    fi
    
    #Merge modules to /tmp/merging_dsc_modules/ModuleFileName
    unzip -q -o $X86Dir/$ModuleFileName -d ./$DscModuleIntermediateDir
    unzip -q -o $X64Dir/$ModuleFileName -d ./$DscModuleIntermediateDir
    
    WorkingDir="./$DscModuleIntermediateDir/$ModuleName"
    
    (
        #Generate Sha256sums
        echo "Generating sha256sum for module $ModuleName..."
        cd $WorkingDir
        find . -type f -print0 | xargs -0 sha256sum |grep -v sha256sums > ./$ModuleName.sha256sums
    
        #Test Sha256sums
        echo "Test $ModuleName.sha256sum..."
        sha256sum -c ./$ModuleName.sha256sums 1>/dev/null
    )

    #Starting signing flow..
    echo "Signing .sha256sums file..."
	echo "Delete $ModuleName.sha256sums from the source container if exists."	
	if delete_blob $SAS_SOURCE_URI $ModuleName.sha256sums ; then
	  echo "delete_blob(): successfully deleted the blob."
	fi
	
	echo "Remove $ModuleName.asc from the destination container if exists."
	if delete_blob $SAS_DEST_URI "$ModuleName.asc" ; then
	  echo "delete_blob(): successfully deleted the blob."
	fi
	
	echo "Upload $ModuleName.sha256sums into source container..."
	write_blob $SAS_SOURCE_URI "$WorkingDir/$ModuleName.sha256sums"
	
	echo "Remove signing.log from destination container. This will trigger interim service to start."
	if delete_blob $SAS_DEST_URI "signing.log" ; then
	  echo "delete_blob(): successfully deleted the blob."
	fi
	
	echo "Wait for interim service to finish signing the file.."
	NUM_OF_RETRIES=0
    while [ $NUM_OF_RETRIES -lt $MaxSignWaitAttempts ]
    do
      echo "Retry attempt number $NUM_OF_RETRIES"
	  if read_blob $SAS_DEST_URI "signing.log" "../$DscModuleIntermediateDir/signing.log" ; then
        echo "found marker file signing.log"
        break
      fi
	  let NUM_OF_RETRIES=$NUM_OF_RETRIES+1
      sleep 30  
    done
	echo "Download the signed $ModuleName.asc file into $WorkingDir"
		
    if ! read_blob $SAS_DEST_URI "$ModuleName.asc" "$WorkingDir/$ModuleName.asc" ; then
      echo "$ModuleName.asc not found in the container destination"
      exit 1
    fi
	
	echo " Cleanup ..."
	echo " Remove  $ModuleName.sha256sums from source container."
	delete_blob $SAS_SOURCE_URI "$ModuleName.sha256sums"
	
	echo " Remove  $ModuleName.asc from source container."
	delete_blob $SAS_DEST_URI "$ModuleName.asc"
	
    (
        echo "Producing .zip file for signed module $ModuleName"
        cd $DscModuleIntermediateDir
        zip -q -r $ModuleName.zip $ModuleName/*
    )

    echo
done

if [ -d "$DscModuleTargetDir" ]
then
    rm -rf "$DscModuleTargetDir"
fi

mkdir -p $DscModuleTargetDir

if ! cp $DscModuleIntermediateDir/*.zip $DscModuleTargetDir/; then
    echo "Failed to copy the signed packages into the target folder"
    exit 1
fi

echo "Finished copying signed packages into the target folder $DscModuleTargetDir."

exit 0

