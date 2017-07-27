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
FLUENTD_CONF_PATH="/etc/opt/microsoft/omsagent/conf/omsagent.d/vmware-solution.conf"
POWERCLI_URI="https://download3.vmware.com/software/vmw-tools/powerclicore/PowerCLI_Core.zip"
POWERCLI_TMP="/tmp"
OMS_AGENT_SERVICE="/opt/microsoft/omsagent/bin/service_control"
SECRET_FILE_PATH="/var/opt/microsoft/omsagent/state/vmware_secret.csv"
IPADDRESS=""
USERNAME=""
PASSWORD=""
SOLUTION="ESXI"
WORKSPACE_ID=""
SHARED_KEY=""
UNINSTALL=""
ADDMACHINE=""

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

getSecret () {
  echo "Enter $SOLUTION Password (hidden)"
  read -s PASSWORD
}

getParameters () {
  echo "OMS Linux Agent Setup"
  echo "---------------------------"
  echo "Enter OMS Workspace ID (Ex format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)"

  # User input for WSID and Key
  read WORKSPACE_ID
  echo "Enter OMS Workspace Primary Key"
  read SHARED_KEY
}

getCredentials () {
  echo "VMware Solution Setup"
  echo "---------------------------"
  echo "Enter 1 to setup solution for vCenter Server (or) any other key to setup solution for ESXI Host"
  # read the user input
  read SETUP_OPTION
  if [ "$SETUP_OPTION" = "1" ]
  then
    SOLUTION="vCenter"
  fi
  echo "Enter $SOLUTION Server IP Address (Ex: 10.123.456.123)"
  read IPADDRESS
  echo "Enter $SOLUTION Username (Ex: administrator@vsphere.local or root)"
  read USERNAME
  getSecret
}

setupLinuxAgent () {
  # Installing / Onboarding the Linux Agent
  echo "Downloading Installation Script"
  echo "Installing the OMS Linux Agent"
  wget $OMS_AGENT$OMS_AGENT_SCRIPT && sh $OMS_AGENT_SCRIPT -w $WORKSPACE_ID -s $SHARED_KEY
  echo "OMS Linux Installation Complete!"
}

setupSecret () {
  # Create the secret file with secure string
  powershell -c "New-Object PsObject -property @{'Server' = \"$IPADDRESS\";'Username' = \"$USERNAME\";'Solution' = \"$SOLUTION\";'SecureString' = \"$PASSWORD\" | ConvertTo-SecureString -asPlainText -Force | ConvertFrom-SecureString -Key (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)} | export-csv -append -path \"$SECRET_FILE_PATH\""
  # Updating the file permission for the secret file
  sudo chown omsagent:omiusers $SECRET_FILE_PATH
}

setupPowershell () {
  echo "Powershell Setup"
  echo "---------------------------"
  # Import the public repository GPG keys
  # curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

  # # Register the Microsoft Ubuntu repository
  # curl https://packages.microsoft.com/config/ubuntu/14.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list

  # # Update apt-get
  # sudo apt-get update

  # # Install PowerShell
  # sudo apt-get install -y powershell

  if [ -f /etc/debian_version ]; then
      # XXX or Ubuntu
    wget https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-alpha.18/powershell_6.0.0-alpha.18-1ubuntu1.14.04.1_amd64.deb
    sudo dpkg -i powershell_6.0.0-alpha.18-1ubuntu1.14.04.1_amd64.deb
  elif [ -f /etc/redhat-release ]; then
    # XXX or CentOS or Fedora
    sudo yum install https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-alpha.18/powershell-6.0.0_alpha.18-1.el7.centos.x86_64.rpm
  elif [ -f /etc/Suse-release ]; then
    # SUSE
  fi

  setupSecret
}

restartOMS () {
  #restart OMS Linux Agent
  sudo $OMS_AGENT_SERVICE restart
}

setupPowerCli () {
  # Downloading PowerCLI
  wget $POWERCLI_URI -O $POWERCLI_TMP"/PowerCLI_Core.zip"
  cd $POWERCLI_TMP
  unzip $POWERCLI_TMP"/PowerCLI_Core.zip"
  #cd $POWERCLI_TMP"/PowerCLI_Core"

  MODULE_PATH=`powershell -c '$env:PSModulePath'`
  for MPATH in $(echo $MODULE_PATH | tr ":" "\n")
  do
    if [ ${MPATH:0:14} = '/opt/microsoft' ]
      then
      unzip PowerCLI.ViCore.zip -d $MPATH
      unzip PowerCLI.Vds.zip -d $MPATH
    fi
  done
}

completeInstallation () {
  restartOMS

  #remove tmp installation files
  #rm $POWERCLI_TMP"/PowerCLI_Core.zip"
  #rm $OMS_AGENT_SCRIPT
}

enterBatchSetup () {
  setupLinuxAgent
  setupPowershell
  setupPowerCli
  completeInstallation
}

enterSetup () {
  getParameters
  getCredentials
  enterBatchSetup
}

stopIngestion () {
  powershell -c 'import-csv '$SECRET_FILE_PATH' | where {$_.Server -ne "'$UNINSTALL'"} | export-csv "/tmp/vmware_secret.csv"'
  mv $SECRET_FILE_PATH $SECRET_FILE_PATH".bkp"
  mv '/tmp/vmware_secret.csv' $SECRET_FILE_PATH

  restartOMS

  echo "VMware solution is removed for the server "$UNINSTALL
}

addMachines () {
  getCredentials
  setupSecret
  restartOMS
}

exitSetup () {
  echo "Setup aborted by user!"
}

initSetup () {
  read -s -n1 key
  case $key in
    $'') enterSetup;;
    $'\e') exitSetup;;
  esac
}

# Extract parameters
while [ $# -ne 0 ]
do
    case "$1" in
        -t|--type)
            SOLUTION=$2
            shift 2
            ;;

        -s|--shared)
            SHARED_KEY=$2
            shift 2
            ;;

        -w|--id)
            WORKSPACE_ID=$2
            shift 2
            ;;
        -h|--id)
            IPADDRESS=$2
            shift 2
            ;;
        -u|--id)
            USERNAME=$2
            shift 2
            ;;
        -r|--remove)
            UNINSTALL=$2
            shift 2
            ;;
        -a|--add)
            ADDMACHINE=$2
            shift 2
            ;;
         *)
            echo "Unknown argument: '$1'" >&2
            echo "Please execute the script with valid arguments" >&2
            exit 1
            ;;
    esac
done

initInstructions () {
  echo "This script will download and install the VMWare modules and Powershell which are subject to the VMWare EULA https://labs.vmware.com/flings/powercli-core and Powershell https://github.com/PowerShell/PowerShell"
  echo "Softwares that will be installed:"
  echo "1. OMS Linux Agent"
  echo "2. Powershell for Linux"
  echo "3. VMWare Solution"
  echo "---------------------------"
}

if [ ! -z "$UNINSTALL" ]
  then
  echo "Removing "$UNINSTALL" from the VMware Solution"
  stopIngestion
elif [ ! -z "$ADDMACHINE" ]
  then
  echo "Onboarding New Machine"
  addMachines
  echo "New Machine Onboarded!"
elif [ -z "$IPADDRESS" ] || [ -z "$USERNAME" ] || [ -z "$SOLUTION" ] || [ -z "$WORKSPACE_ID" ] || [ -z "$SHARED_KEY" ]
  then
  initInstructions
  echo "Press Enter to continue installation, Esc to Exit."
  initSetup
else
  initInstructions
  getSecret
  enterBatchSetup
fi
