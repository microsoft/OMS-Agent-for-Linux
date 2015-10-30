# Package Requirements
 **Required package** 	| **Description** 	| **Minimum version**
--------------------- | --------------------- | -------------------
 Glibc |	GNU C Library	| 2.5-12 
Openssl	| OpenSSL Libraries | 0.9.8b or 1.0
Curl | cURL web client | 7.15.5
PAM | Pluggable authentication Modules	 | 

**Note**: Either rsyslog or syslog-ng are required to collect syslog messages. The default syslog daemon on version 5 of Red Hat Enterprise Linux, CentOS, and Oracle Linux version (sysklog) is not supported for syslog event collection. To collect syslog data from this version of these distributions, the rsyslog daemon should be installed and configured to replace sysklog, 

# Install the Linux Agent
The Linux agent for Operations Management Suite comprises multiple packages. The release file contains the following packages, available by running the shell bundle with `--extract`:

**Package** | **Version** | **Description**
----------- | ----------- | --------------
omsagent | 1.0.0 | The Operations Management Suite Agent for Linux
omsconfig | 1.1.0 | Configuration agent for the OMS Agent
omi | 1.0.8.3 | Open Management Infrastructure (OMI) -- a lightweight CIM Server
scx | 1.6.1 | OMI CIM Providers for operating system performance metrics
apache-cimprov | 1.0.0 | Apache HTTP Server performance monitoring provider for OMI. Only installed if Apache HTTP Server is detected.
mysql-cimprov | 1.0.0 | MySQL Server performance monitoring provider for OMI. Only installed if MySQL/MariaDB server is detected.

## Upgrade from a Previous Release
If you have installed a prior Preview version of the Linux agent for Operations Management Suite, it must be removed (and configuration files purged) prior to installing this version. Upgrade from prior versions is not supported in this release.

### Removing Prior Versions
**CentOS Linux, Oracle Linux, RHEL, SLES**
```
sudo rpm -e omsagent scx omi
sudo rm -f /etc/opt/microsoft/omsagent/conf/omsagent.conf
```

**Debian, Ubuntu**
```
dpkg -P omsagent scx omi
sudo rm -f /etc/opt/microsoft/omsagent/conf/omsagent.conf
```

## Additional Installation Artifacts
After installing the Linux agent for OMS packages, the following additional system-wide configuration changes are applied. These artifacts are removed when the omsagent package is uninstalled.
* A non-privileged user named: `omsagent` is created. This is the account the omsagent daemon runs as
* A sudoers “include” file is created at /etc/sudoers.d/omsagent This authorizes omsagent to restart the syslog and omsagent daemons. If sudo “include” directives are not supported in the installed version of sudo, these entries will be written to /etc/sudoers.
* •	The syslog configuration is modified to forward a subset of events to the agent. For more information, see the **Configuring Data Collection** section below

## Steps to install the OMS Agent for Linux
The Linux agent is provided in a self-extracting and installable shell script bundle. This bundle contains Debian and RPM packages for each of the agent components and can be installed directly or extracted to retrieve the individual packages. One bundle is provided for x64 architectures and one for x86 architectures. 

**Installing the agent**

1. Transfer the appropriate bundle (x86 or x64) to your Linux computer, using scp/sftp.
2. Install the bundle by using the `--install` or `--upgrade` argument. Note: use the `--upgrade` argument if any existing packages are installed, as would be the case if the Linux agent for System Center Operations Manager is already installed. To onboard to Operations Management Suite during installation, provide the `-w <WorkspaceID>` and `-s <Shared Key>` parameters.

**To install and onboard directly:**
```
sudo sh ./omsagent-1.0.0-27.universal.x86.sh --install –w <workspaceid> -s <shared key>
```

**To install the agent packages and onboard at a later time:**
```
sudo sh ./omsagent-1.0.0-27.universal.x86.sh --install 
```

**To extract the agent packages from the bundle without installing:**
```
sudo sh ./omsagent-1.0.0-27.universal.x86.sh –-extract
```

**All bundle operations:**
```
Options:
  --extract              Extract contents and exit.
  --force                Force upgrade (override version checks).
  --install              Install the package from the system.
  --purge                Uninstall the package and remove all related data.
  --remove               Uninstall the package from the system.
  --restart-deps         Reconfigure and restart dependent service
  --upgrade              Upgrade the package in the system.
  --debug                use shell debug mode.

  -w id, --id id         Use workspace ID <id> for automatic onboarding.
  -s key, --shared key   Use <key> as the shared key for automatic onboarding.

  -? | --help            shows this usage text.
```

**MD5 Checksums**
```
```

## Onboarding with Operations Management Suite
If a workspace ID and key were not provided during the bundle installation, the agent must be subsequently registered with Operations Management Suite.

### Onboarding using the command line
Run the omsadmin.sh command supplying the workspace id and key for your workspace. This command must be run as root (w/ sudo elevation) or run as the created omsagent user:
```
cd /opt/microsoft/omsagent/bin
sudo ./omsadmin.sh -w <WorkspaceID> -s <Shared Key>
```

### Onboarding using a file
1.	Create the file /etc/omsagent-onboard.conf The file must be writable for the user omsagent. 
sudo su omsagent vi /etc/omsagent-onboard.conf
2.	Insert the following lines in the file with your Workspace ID and Shared Key:
`WORKSPACE_ID=<WorkspaceID>`
`SHARED_KEY=<Shared Key>`
3.	Restart the omsagent:
sudo service omsagent restart
4.	The file will be deleted on successful onboarding

## Viewing Linux Data
### Viewing Syslog events
From within the Operations Management Suite portal, access the **Log Search** tile. Predefined syslog search queries can be found in the **Log Management** grouping.
![](https://github.com/MSFTOSSMgmt/OMS-Agent-for-Linux/blob/master/docs/pictures/SyslogLogManagement.png?raw=true)

### Viewing Performance Data
From within the Operations Management Suite portal, access the Log Search tile. Enter in the search bar. "* (Type=Perf)" to view all performance counters.
![](https://github.com/MSFTOSSMgmt/OMS-Agent-for-Linux/blob/master/docs/pictures/PerfSearchView.png?raw=true)

### Viewing Nagios Alerts
From within the Operations Management Suite portal, access the Log Search tile. Enter in the search bar, "* (Type=Alert) SourceSystem=Nagios" to view all Nagios Alerts.
![](https://github.com/MSFTOSSMgmt/OMS-Agent-for-Linux/blob/master/docs/pictures/NagiosSearchView.png?raw=true)

## Configuring Data Collection
Data to collect (e.g. syslog events and performance metrics) can be defined centrally in the Operations Management Suite portal, or on the agents directly.  Selections that you define in the portal for data collection will be applied to the agents within 5 minutes. 

### Configuring Syslog collection from the OMS portal
* Log into the Operations Management Suite **Portal**
* From the **Overview** dashboard, select **Settings**
* From the Settings page, click on the **Data** link 
* Select **Syslogs** from the left-hand settings list
* Add or remove *facilities* to collect. For each facility, you can select relevant *severities* to collect

![](https://github.com/MSFTOSSMgmt/OMS-Agent-for-Linux/blob/master/docs/pictures/SyslogConfig.png?raw=true)

### Configuring Linux Performance Counter collection from the OMS portal
* Log into the Operations Management Suite **Portal**
* From the **Overview** dashboard, select **Settings**
* From the Settings page, click on the **Data**  link 
* Select **Linux performance counters** from the left-hand settings list
* Add or remove performance counters to collect. A complete list of available performance counters is available in the Appendix of this document. 
 * You can define a collection interval for each *Object* (i.e. category of performance counters).
 * Optionally, you can filter all performance counters for an *Object to a subset of instances. This is done by providing a Regular Expression value for the **InstanceName** input. For example: 
   * * - will match all instances
    * **(/|/var)** – will match Logical Disk instances named: `/` or `/var`
    * **_Total** – will match Processor instances named _Total

![](https://github.com/MSFTOSSMgmt/OMS-Agent-for-Linux/blob/master/docs/pictures/PerfConfig.png?raw=true)

## Enabling Application Performance Counters
### Enabling MySQL Performance Counters
If MySQL Server or MariaDB Server is detected on the computer when the omsagent bundle is installed a performance monitoring provider for MySQL Server will be automatically installed. This provide connects to the local MySQL/MariaDB server to expose performance statistics. MySQL user credentials must be configured so that the provider can access the MySQL Server.

To define a default user account for the MySQL server on localhost:
*Note: the credentials file must be readable by the omsagent account. Running the mycimprovauth command as omsgent is recommended.*

```
sudo su omsagent -c '/opt/microsoft/mysql-cimprov/bin/mycimprovauth default 127.0.0.1 <username> <password>'

sudo service omiserverd restart
```
Alternatively, you can specify the required MySQL credentials in a file, by creating the file: `/var/opt/microsoft/mysql-cimprov/auth/omsagent/mysql-auth`. For more information on managing MySQL credentials for monitoring through the mysql-auth file, see **Appendix C** of this document.

Reference the **Appendix B** of this document for details on object permissions required by the MySQL user to collect MySQL Server performance data. 

### Enabling Apache HTTP Server Performance Counters
If Apache HTTP Server is detected on the computer when the omsagent bundle is installed, a performance monitoring provider for Apache HTTP Server will be automatically installed. This provider relies on an Apache “module” that must be loaded into the Apache HTTP Server in order to access performance data. The module can be loaded with the following command:
```
sudo /opt/microsoft/apache-cimprov/bin/apache_config.sh -c
```

To unload the Apache monitoring module, run the following command:
```
sudo /opt/microsoft/apache-cimprov/bin/apache_config.sh -u
```

## Configuring Collected Data on the Linux Computer
Syslog events and performance counters to collect can be specified in configuration files on the Linux computers. *If you opt to configure data collection through editing of the agent configuration files, you should disable the centralized configuration*.  Instructions are provided below to configure data collection in the agent’s configuration files as well as to disable central configuration for all Linux agents, or individual computers. 

### Disabling central configuration
#### Diabling central configuration for all Linux computers
TODO:
#### Disabling central configuration for an individual Linux computer
The centralized configuration of data collection can be disabled for an individual Linux computer with the OMS_MetaConfigHelper.py script.  This can be useful if a subset of computers should have a specialized configuration. 

To disable centralized configuration:
```
sudo /opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py --disable
```

To re-enable centralized configuration:
```
sudo /opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py –enable
```

### Syslog events
Syslog events are sent from the syslog daemon (e.g. rsyslog or syslog-ng) to a local port the agent is listening on (by default port 25224). When the agent is installed, a default syslog configuration is applied. This can be found at:
•	Rsyslog: `/etc/rsyslog.d/rsyslog-oms.conf`
•	Syslog-ng: `/etc/syslog-ng/syslog-ng.conf`
The default OMS Agent syslog configuration uploads syslog events from all facilities with a severity of warning or higher. 
*Note: if you edit the syslog configuration, the syslog daemon must be restarted for the changes to take effect.*
 
The default syslog configuration for the Linux agent for OMS is:

#### Rsyslog
```
kern.warning       @127.0.0.1:25224
user.warning       @127.0.0.1:25224
daemon.warning     @127.0.0.1:25224
auth.warning       @127.0.0.1:25224
syslog.warning     @127.0.0.1:25224
uucp.warning       @127.0.0.1:25224
authpriv.warning   @127.0.0.1:25224
ftp.warning        @127.0.0.1:25224
cron.warning       @127.0.0.1:25224
local0.warning     @127.0.0.1:25224
local1.warning     @127.0.0.1:25224
local2.warning     @127.0.0.1:25224
local3.warning     @127.0.0.1:25224
local4.warning     @127.0.0.1:25224
local5.warning     @127.0.0.1:25224
local6.warning     @127.0.0.1:25224
local7.warning     @127.0.0.1:25224
```

#### Syslog-ng
```
#OMS_facility = all
filter f_warning_oms { level(warning); };
destination warning_oms { tcp("127.0.0.1" port(25224)); };
log { source(src); filter(f_warning_oms); destination(warning_oms); };
```

### Performance metrics
Performance metrics to collect are controlled by the configuration in `/etc/opt/microsoft/omsagent/conf/omsagent.conf`. The appendix to this document details available classes and metrics in this release of the agent.

Each Object (or category) of performance metrics to collect should be defined in the configuration file as a single `<source>` element. The syntax follows the pattern:
```
<source>
  type oms_omi  
  object_name "Processor"
  instance_regex ".*"
  counter_name_regex ".*"
  interval 30s
</source>
```

The configurable parameters of this element are:
* **Object_name**: the object name for the collection. Reference the objects and counters listed in the Appendix of this document
* **Instance_regex**: a *regular expression* defining which instances to collect. The value: “.*” specifies all instances. To collect processor metrics for only the _Total instance, you could specify “_Total”. To collect process metrics for only the crond or sshd instances, you could specify: “(crond|sshd)”. 
* **Counter_name_regex**: a *regular expression* defining which counters (for the object) to collect. Reference the objects and counters listed in the Appendix of this document. To collect all counters for the object, specify: “.*”. To collect only swap space counters for the memory object, you could specify: “.+Swap.+”
* **Interval**: The frequency at which the object's counters are collected

The default configuration for a performance metric is:
```
<source>
  type oms_omi
  object_name "Physical Disk"
  instance_regex ".*"
  counter_name_regex ".*"
  interval 5m
</source>

<source>
  type oms_omi
  object_name "Logical Disk"
  instance_regex ".*
  counter_name_regex ".*"
  interval 5m
</source>

<source>
  type oms_omi
  object_name "Processor"
  instance_regex ".*
  counter_name_regex ".*"
  interval 30s
</source>

<source>
  type oms_omi
  object_name "Memory"
  instance_regex ".*"
  counter_name_regex ".*"
  interval 30s
</source>
```

### Nagios Alerts
To collect alerts from a Nagios server, the following configuration changes must be made:
•	Grant the user **omsagent** read access to the Nagios log file (i.e. `/var/log/nagios/nagios.log`). Assuming the nagios.log file is owned by the group `nagios`, you can add the user **omsagent** to the **nagios** group. 
```
sudo usermod –a -G nagios omsagent
```
•	Modify the `omsagent.conf` configuration file (`/etc/opt/microsoft/omsagent/conf/omsagent.conf`). Ensure the following entries are present and not commented out:
```
<source>
  type tail
  #Update path to point to your nagios.log
  path /var/log/nagios/nagios.log
  format none
  tag oms.nagios
</source>

<filter oms.nagios>
  type filter_nagios_log
</filter>
```

* Restart the omsagent daemon
```
sudo service omsagent restart
```
### Zabbix Alerts

## Agent Logs
The logs for the Operations Management Suite Agent for Linux can be found at: 
`/var/opt/microsoft/omsagent/log/`
The logs for the omsconfig (agent configuration) program can be found at: 
`/var/opt/microsoft/omsconfig/log/`
Logs for the OMI and SCX components (which provide performance metrics data) can be found at:
`/var/opt/omi/log/ and /var/opt/microsoft/scx/log`

## Uninstalling the OMS Agent for Linux
The agent packages can be uninstalled using dpkg or rpm, or by running the bundle .sh file with the `--remove` argument. 

**Debian & Ubuntu:**
```
> sudo dpkg –P omsconfig
> sudo dpkg -P omsagent
> sudo dpkg -P scx
> sudo dpkg -P omi
```

**CentOS, Oracle Linux, RHEL, and SLES:**
```
> sudo rpm –e omsconfig
> sudo rpm -e omsagent
> sudo rpm -e scx
> sudo rpm -e omi
```

## Compatibility with System Center Operations Manager
The Operations Management Suite Agent for Linux shares agent binaries with the System Center Operations Manager agent. Installing the OMS Agent for Linux on a system currently managed by Operations Manager upgrades the OMI and SCX packages on the computer to a newer version. In this preview release, the OMS and System Center 2012 R2 Agents for Linux are compatible. **System Center 2012 SP1 and earlier versions are currently not compatible or supported with the OMS Agent for Linux**

**Note:** if the OMS Agent for Linux is installed to a computer that is not currently managed by Operations Manager, and you then wish to manage the computer with Operations Manager, you must modify the OMI configuration prior to discovering the computer. **This step is *not* needed if the Operations Manager agent is installed before the OMS Agent for Linux.**

### To enable the OMS Agent for Linux to communicate with System Center Operations Manager:
* Edit the file `/etc/opt/omi/conf/omiserver.conf`
* Ensure that the line beginning with **httpsport=** defines the port 1270. Such as:
`httpsport=1270`
* Restart the OMI server:
`service omiserver restart` or `systemctl restart omiserver`

## Known Limitations
* **Ubuntu 15.10**
Ubuntu Server version 15.10 is not supported in this preview
* **Azure Diagnostics**
For Linux virtual machines running in Azure, additional steps are required to allow data collection by Azure Diagnotstics and Operations Management Suite. To install the OMS Agent for Linux on a Linux server with the Azure Diagnostics agent, perform the following steps:
TODO
* **Sysklog is not supported**
Either rsyslog or syslog-ng are required to collect syslog messages. The default syslog daemon on version 5 of Red Hat Enterprise Linux, CentOS, and Oracle Linux version (sysklog) is not supported for syslog event collection. To collect syslog data from this version of these distributions, the rsyslog daemon should be installed and configured to replace sysklog. For more information on replacing sysklog with rsyslog, see: http://wiki.rsyslog.com/index.php/Rsyslog_on_CentOS_success_story#Install_the_newly_built_rsyslog_RPM

