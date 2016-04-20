#!/bin/bash

#Assumes that ./x64 and ./x86 exist and contain the arch-specific copies of a DSC resource module

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

IntermediateDir="../intermediate"
TargetDir="../target"
DscModuleIntermediateDir="$IntermediateDir/merging_dsc_modules"
DscModuleTargetDir="$TargetDir/dsc_modules"
X64Dir="./x64"
X86Dir="./x86"
TestSigningDir=$1

if [ "$TestSigningDir" = "" ]
then
    TestSigningDir="../test/config/testsigning"
fi

if [ -d "$TestSigningDir" ]
then
    gpg --list-secret-keys
    if [ $? != 0 ]
    then
        echo "Failed to run the gpg command"
        exit 1
    fi

    gpg --list-secret-keys | grep -q '2048R/8C3B51C6'
    if [ $? != 0 ]
    then
        TestGPGKey="$TestSigningDir/gpg.asc"
        if [ -f "$TestGPGKey" ]
        then
            echo "Import the test GPG key"
            gpg --import $TestGPGKey
            if [ $? != 0 ]
            then
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

    if [ ! -f "$SigningKeyFilePath" ]
    then
        echo "GPG key file is not found"
        exit 1
    fi

    if [ ! -f "$SigningKeyPassphrase" ]
    then
        echo "GPG key passphrase is not found"
        exit 1
    fi
else
    echo "Signing key directory doesn't exist at location: $TestSigningDir"
    exit 1
fi

set -e

if [ -d "$DscModuleIntermediateDir" ]
then
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
    unzip -o $X86Dir/$ModuleFileName -d ./$DscModuleIntermediateDir
    unzip -o $X64Dir/$ModuleFileName -d ./$DscModuleIntermediateDir
    
    WorkingDir="./$DscModuleIntermediateDir/$ModuleName/"
    
    (
        #Generate Sha256sums
        echo "Generating sha256sums..."
        cd $WorkingDir
        find . -type f -print0 | xargs -0 sha256sum |grep -v sha256sums > ./$ModuleName.sha256sums
    
        #Test Sha256sums
        echo "Test sha256sums..."
        sha256sum -c $ModuleName.sha256sums
    )

    #Test sign module
    echo "Signing .sha256sums file..."
    if ! cat $SigningKeyPassphrase | gpg --no-default-keyring --keyring $SigningKeyFilePath --yes --passphrase-fd 0 --output ./$WorkingDir/$ModuleName.asc --armor --detach-sign ./$WorkingDir/$ModuleName.sha256sums; then
        echo "Failed to sign the .sha256sums file"
        exit 1
    fi

    echo "Verifying signature..."
    if ! gpg --no-default-keyring --keyring $SigningKeyFilePath --verify  ./$WorkingDir/$ModuleName.asc ./$WorkingDir/$ModuleName.sha256sums; then
        echo "Signature is invalid"
        exit 1
    fi

    (
        echo "Producing .zip file"
        cd $DscModuleIntermediateDir
        zip -r $ModuleName.zip $ModuleName/*
    )
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
