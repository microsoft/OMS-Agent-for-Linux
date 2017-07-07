#!/bin/sh

#
# This  script will download and install the VMWare modules which are subject to the VMWare EULA https://labs.vmware.com/flings/powercli-core
#

#
# Easy download/install/onboard script for the VMware Solution on OMS Linux Agent
#

# Path Variables
OMS_AGENT="https://raw.githubusercontent.com/Microsoft/OMS-Agent-for-Linux/master/installer/scripts/"
OMS_AGENT_SCRIPT="onboard_agent.sh"
PS_MODULES_PATH=~/.local/share/powershell/Modules
FLUENTD_CONF_PATH="/etc/opt/microsoft/omsagent/conf/omsagent.d/vmware-solution.conf"
POWERCLI_URI="https://download3.vmware.com/software/vmw-tools/powerclicore/PowerCLI_Core.zip"
POWERCLI_TMP="/tmp"
OMS_AGENT_SERVICE="/opt/microsoft/omsagent/bin/service_control"
SECRET_FILE_PATH="/opt/microsoft/omsagent/bin/vmware_secret.csv"
IPADDRESS=""
USERNAME=""
PASSWORD=""
SOLUTION="ESXI"

setupLinuxAgent () {
  echo "OMS Linux Agent Setup"
  echo "---------------------------"
  echo "Enter OMS Workspace ID"

  # User input for WSID and Key
  read WORKSPACE_ID
  echo "Enter OMS Workspace Primary Key"
  read SHARED_KEY

  echo "VMware Solution Setup"
  echo "---------------------------"
  echo "Enter 1 to setup solution for vCenter Server (or) any other key to setup solution for ESXI Host"
  # read the user input
  read SETUP_OPTION
  if [ "$SETUP_OPTION" = "1" ]
  then
    SOLUTION="vCenter"
  fi
  echo "Enter $SOLUTION Server IP Address"
  read IPADDRESS
  echo "Enter $SOLUTION Username"
  read USERNAME
  echo "Enter $SOLUTION Password"
  read -s PASSWORD

  echo "Downloading Installation Script"
  echo "Installing the OMS Linux Agent"

  # Installing / Onboarding the Linux Agent
  wget $OMS_AGENT$OMS_AGENT_SCRIPT && sh $OMS_AGENT_SCRIPT -w $WORKSPACE_ID -s $SHARED_KEY
  echo "OMS Linux Installation Complete!"
}

setupSecret () {
  # Create the secret file with secure string
  powershell -c "New-Object PsObject -property @{'Server' = \"$IPADDRESS\";'Username' = \"$USERNAME\";'Solution' = \"$SOLUTION\";'SecureString' = \"$PASSWORD\" | ConvertTo-SecureString -asPlainText -Force | ConvertFrom-SecureString -Key (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)} | export-csv \"$SECRET_FILE_PATH\""
}

setupPowershell () {
  echo "Powershell Setup"
  echo "---------------------------"
  # Import the public repository GPG keys
  curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

  # Register the Microsoft Ubuntu repository
  curl https://packages.microsoft.com/config/ubuntu/14.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list

  # Register the Microsoft Ubuntu repository
  # curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list

  # Update apt-get
  sudo apt-get update

  # Install PowerShell
  sudo apt-get install -y powershell

  setupSecret
}

setupPowerCli () {
  # Downloading PowerCLI
  wget $POWERCLI_URI -O $POWERCLI_TMP"/PowerCLI_Core.zip"
  mkdir -p $PS_MODULES_PATH
  cd $POWERCLI_TMP
  unzip $POWERCLI_TMP"/PowerCLI_Core.zip"
  #cd $POWERCLI_TMP"/PowerCLI_Core"

  # Copying the modules
  unzip PowerCLI.ViCore.zip -d $PS_MODULES_PATH
  unzip PowerCLI.Vds.zip -d $PS_MODULES_PATH
}

completeInstallation () {
  # Updating the file permission for the secret file
  sudo chown omsagent:omiusers $SECRET_FILE_PATH

  #restart OMS Linux Agent
  sudo $OMS_AGENT_SERVICE restart

  #remove tmp installation files
  #rm $POWERCLI_TMP"/PowerCLI_Core.zip"
  #rm $OMS_AGENT_SCRIPT
}

enter_setup () {
  setupLinuxAgent
  setupPowershell
  setupPowerCli
  completeInstallation
}

stop_ingestion() {
  rm SECRET_FILE_PATH

  #restart OMS Linux Agent
  sudo $OMS_AGENT_SERVICE restart
}

exit_setup () {
  echo "Setup aborted by user!"
}

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
echo "This script will download and install the VMWare modules and Powershell which are subject to the VMWare EULA https://labs.vmware.com/flings/powercli-core and Powershell https://github.com/PowerShell/PowerShell"
echo "Softwares that will be installed:"
echo "1. OMS Linux Agent"
echo "2. Powershell for Linux"
echo "3. VMWare Solution"
echo "---------------------------"
echo "Press Enter to continue installation, Esc to Exit."

read -s -n1 key
case $key in
  $'') enter_setup;;
  $'\e') exit_setup;;
esac