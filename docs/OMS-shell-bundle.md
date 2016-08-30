### What is the OMS shell bundle?  The OMS agent for Linux is provided
in a shell script bundle which is essentially a shell script to which
a binary payload is appended. This payload is a tar file that is
created by copying the appropriate .deb and .rpm files collected from
the specified version of omi, dsc and scx, as well as the oss-kits.

### How is it built?
[create_bundle.sh](../installer/bundle/create_bundle.sh)
is the script that will create the shell bundle given an existing tar
file payload. This script takes in four parameters: 
 1. Target directory - the dir path where the bundles are created 
 2. Intermediate directory - the dir path to the intermediate directory where all the
intermediate targets are saved, separate from the final targets 
 3. tar file - the tar file that contains the .deb/.rpm files 
 4. Install type - the value is "DPKG" for a .deb bundle, "RPM" for an .rpm bundle,
blank for an all-inclusive bundle  

This script edits the bundle file i.e.
[bundle_skel.sh](../installer/bundle/bundle_skel.sh)
and enters hard-coded values for the variables: TAR_FILE, &nbsp;
OMI_PKG, &nbsp; OMS_PKG,  &nbsp;DSC_PKG,  &nbsp;SCX_PKG,
&nbsp;SCRIPT_LEN,  &nbsp;SCRIPT_LEN_PLUS_ONE  &nbsp;and &nbsp;
INSTALL_TYPE. After these values are in place, the script creates the
bundle in the target directory.

The
[Makefile](../build/Makefile)
is where the bundle creation is executed. Here, the .rpm and .deb
packages are built using the installbuilder. The files from these
packages along with the oss-kits are copied over to create the tar
files.The create_bundle.sh script is then run to create the omsagent
shell bundle in the target directory using the tar file. All bundles
are put in the target directory once the build is complete.

### Installing the bundle: 

Instructions for installing the agent and information on other bundle 
operations can be found [here.](OMS-Agent-for-Linux.md#steps-to-install-the-oms-agent-for-linux)

When running bundle install, before actual
installation, the script will check if the correct bundle is being
installed based on the processor architecture (x64 vs. x86). It will
also check if the kit type being referenced to by the bundle is
correct (rpm vs. deb). If either of these tests fail, the script will
cleanup and exit without installation.
