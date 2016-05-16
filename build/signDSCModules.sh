#!/bin/bash

# Assume we're running from superproject (with version file)

if [ ! -f omsagent.version ]; then
    echo "Is current directory wrong? Can't find version file omsagent.version ..."
    exit 1
fi

# Read in the version file

source omsagent.version

if [ -z "$OMS_BUILDVERSION_MAJOR" -o -z "$OMS_BUILDVERSION_MINOR" -o -z "$OMS_BUILDVERSION_PATCH" -o -z "$OMS_BUILDVERSION_BUILDNR" ]; then
    echo "Missing environment variables for build version"
    exit 1
fi

BUILD_VERS=$OMS_BUILDVERSION_MAJOR.$OMS_BUILDVERSION_MINOR.$OMS_BUILDVERSION_PATCH-$OMS_BUILDVERSION_BUILDNR

# We assume that our build share is mounted at: /mnt/ostcdata. Verify that
# our build directory is under that as expected ...

BUILD_BASEDIR=/mnt/ostcdata/OSTCData/Builds/omsagent/develop

if [ ! -d $BUILD_BASEDIR ]; then
    echo "Not finding Build share mounted at $BUILD_BASEDIR ..."
    exit 1
fi

BUILD_BASEDIR=${BUILD_BASEDIR}/${BUILD_VERS}

if [ ! -d $BUILD_BASEDIR ]; then
    echo "Not finding build output for version $BUILD_VERS at: $BUILD_BASEDIR"
    exit 1
fi

zip -L >/dev/null 2>&1
if [ $? != 0 ]; then
    echo "zip must be installed"
    exit 1
fi

unzip -Z >/dev/null 2>&1
if [ $? != 0 ]; then
    echo "unzip must be installed"
    exit 1
fi

# Drop into build directory for remainder of operations

cd omsagent/build

# Set definitions and sign

IntermediateDir="../intermediate"
TargetDir="../target"
DscModuleIntermediateDir="$IntermediateDir/merging_dsc_modules"
DscModuleTargetDir="$TargetDir/dsc_signed"
X64Dir="$BUILD_BASEDIR/Linux_ULINUX_1.0_x64_64_Release/dsc"
X86Dir="$BUILD_BASEDIR/Linux_ULINUX_1.0_x86_32_Release/dsc"
TestSigningDir=$1

if [ "$TestSigningDir" = "" ]; then
    TestSigningDir="../test/config/testsigning"
fi

if [ -d "$TestSigningDir" ]; then
    gpg --version > /dev/null
    if [ $? != 0 ]; then
        echo "Failed to run the gpg command"
        exit 1
    fi

    gpg --list-secret-keys | grep -q '2048R/8C3B51C6'
    if [ $? != 0 ]; then
        TestGPGKey="$TestSigningDir/gpg.asc"
        if [ -f "$TestGPGKey" ]; then
            echo "Import the test GPG key"
            gpg --import $TestGPGKey
            if [ $? != 0 ]; then
                echo "Failed to import the test GPG key"
                exit 1
            fi
        else
            echo "Did not find the test GPG key at $TestGPGKey"
            exit 1
        fi
    fi  

    SigningKeyFilePath="$TestSigningDir/signingkeys.gpg"
    SigningKeyPassphrase="$TestSigningDir/passphrase"

    if [ ! -f "$SigningKeyFilePath" ]; then
        echo "GPG key file is not found"
        exit 1
    fi

    if [ ! -f "$SigningKeyPassphrase" ]; then
        echo "GPG key passphrase is not found"
        exit 1
    fi
else
    echo "Signing key directory doesn't exist at location: $TestSigningDir"
    exit 1
fi

set -e

if [ -d "$DscModuleIntermediateDir" ]; then
    rm -rf "$DscModuleIntermediateDir"
fi

mkdir -p "$DscModuleIntermediateDir"

for ModuleFilePath in $X64Dir/*.zip;
do
    # expected file name: ./x64/nxOMSPlugin_1.0.zip
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
    
    #Merge modules to ./intermediate/ModuleFileName
    unzip -q -o $X86Dir/$ModuleFileName -d ./$DscModuleIntermediateDir
    unzip -q -o $X64Dir/$ModuleFileName -d ./$DscModuleIntermediateDir
    
    WorkingDir="./$DscModuleIntermediateDir/$ModuleName/"
    
    (
        #Generate Sha256sums
        echo "Generating sha256sums..."
        cd $WorkingDir
        find . -type f -print0 | xargs -0 sha256sum |grep -v sha256sums > ./$ModuleName.sha256sums
    
        #Test Sha256sums
        echo "Test sha256sums..."
        sha256sum --quiet -c $ModuleName.sha256sums
    )

    #Test sign module
    echo "Signing .sha256sums file..."
    if ! cat $SigningKeyPassphrase | gpg --quiet --batch --no-default-keyring --keyring $SigningKeyFilePath --yes --passphrase-fd 0 --output ./$WorkingDir/$ModuleName.asc --armor --detach-sign ./$WorkingDir/$ModuleName.sha256sums; then
        echo "Failed to sign the .sha256sums file"
        exit 1
    fi

    echo "Verifying signature..."
    if ! gpg --quiet --no-default-keyring --keyring $SigningKeyFilePath --verify  ./$WorkingDir/$ModuleName.asc ./$WorkingDir/$ModuleName.sha256sums; then
        echo "Signature is invalid"
        exit 1
    fi

    (
        echo "Producing .zip file"
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
    echo "Failed to copy the merged packages into the target folder"
    exit 1
fi

exit 0
