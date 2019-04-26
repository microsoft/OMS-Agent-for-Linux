# Troubleshooting Guide for OMS Agent for Linux
The following document provides a quick series of steps and procedures to diagnose and troubleshoot common issues.
If none of these steps work for you the following channels for help are also available
* Customers with Premier support can log a support case via [Premier](https://premier.microsoft.com/)
* Customers with Azure support agreements can log support cases [in the Azure portal](https://manage.windowsazure.com/?getsupport=true)
* Diagnosing OMI Problems with the [OMI troubleshooting guide](https://github.com/Microsoft/omi/blob/master/Unix/doc/diagnose-omi-problems.md)
* File a [GitHub Issue](https://github.com/Microsoft/OMS-Agent-for-Linux/issues)
* Feedback forum for ideas and bugs [http://aka.ms/opinsightsfeedback](http://aka.ms/opinsightsfeedback)

# Table of Contents
- [Important Log Locations and Log Collector Tool](#important-log-locations-and-log-collector-tool)
- [Important Configuration Files](#important-configuration-files)
- [Installation Error Codes](#installation-error-codes)
- [Onboarding Error Codes](#onboarding-error-codes)
- [Enable Debug Logging](#enable-debug-logging)
- [OMS output plugin debug](#oms-output-plugin-debug)
- [Verbose output](#verbose-output)
- [My forwarded Syslog messages are not showing up!](#my-forwarded-syslog-messages-are-not-showing-up)
- [I'm unable to connect through my proxy to OMS](#im-unable-to-connect-through-my-proxy-to-oms)
- [I'm getting a 403 when I'm trying to onboard!](#im-getting-a-403-when-im-trying-to-onboard)
- [I'm seeing a 500 Error and 404 Error in the log file right after onboarding](#im-seeing-a-500-error-and-404-error-in-the-log-file-right-after-onboarding)
- [I'm getting Errno address already in use in omsagent log file](#im-getting-errno-address-already-in-use-in-omsagent-log-file)
- [I'm unable to uninstall omsagent using purge option](#im-unable-to-uninstall-omsagent-using-purge-option)
- [My Nagios data is not showing up in the OMS Portal!](#my-nagios-data-is-not-showing-up-in-the-oms-portal)
- [I'm not seeing any Linux data in the OMS Portal](#im-not-seeing-any-linux-data-in-the-oms-portal)
- [My portal side configuration for (Syslog/Linux Performance Counter) is not being applied](#my-portal-side-configuration-for-sysloglinux-performance-counter-is-not-being-applied)
- [I'm not seeing my Custom Log Data in the OMS Potal](#im-not-seeing-my-custom-log-data-in-the-oms-portal)
- [I'm re-onboarding to a new workspace](#im-re-onboarding-to-a-new-workspace)

## Important Log Locations and Log Collector Tool

 File | Path
 ---- | -----
 OMS Agent for Linux Log File | `/var/opt/microsoft/omsagent/<workspace id>/log/omsagent.log `
 OMS Agent Configuration Log File | `/var/opt/microsoft/omsconfig/omsconfig.log`

 We recommend you to use our log collector tool to retrieve important logs for troubleshooting or before submitting a github issue. You can read more about the tool and how to run it [here](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/tools/LogCollector/OMS_Linux_Agent_Log_Collector.md)

## Important Configuration Files

 Category | File Location
 ----- | -----
 Syslog | `/etc/syslog-ng/syslog-ng.conf` or `/etc/rsyslog.conf` or `/etc/rsyslog.d/95-omsagent.conf`
 Performance, Nagios, Zabbix, OMS output and general agent | `/etc/opt/microsoft/omsagent/<workspace id>/conf/omsagent.conf`
 Additional configurations | `/etc/opt/microsoft/omsagent/<workspace id>/conf/omsagent.d/*.conf`

 **Note:** Editing configuration files for performance counters & syslog is overwritten if Portal Configuration is enabled. Disable configuration in the OMS Portal (all nodes) or for single nodes run the following:

 `sudo su omsagent -c /opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py --disable`

## Installation Error Codes

| Error Code | Meaning |
| --- | --- |
| NOT_DEFINED | Because the necessary dependencies are not installed, the auoms auditd plugin will not be installed | Installation of auoms failed; Install package auditd |
| 2 | Invalid option provided to the shell bundle; Run `sudo sh ./omsagent-*.universal*.sh --help` for usage |
| 3 | No option provided to the shell bundle; Run `sudo sh ./omsagent-*.universal*.sh --help` for usage |
| 4 | Invalid package type OR invalid proxy settings; omsagent-*rpm*.sh packages can only be installed on RPM-based systems, and omsagent-*deb*.sh packages can only be installed on Debian-based systems; We recommend that you use the universal installer from the [latest release](https://github.com/Microsoft/OMS-Agent-for-Linux/releases/latest). Also [review](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/docs/Troubleshooting.md#im-unable-to-connect-through-my-proxy-to-oms) your proxy settings. |
| 5 | The shell bundle must be executed as root OR there was 403 error returned during onboarding; Run your command using `sudo` |
| 6 | Invalid package architecture OR there was error 200 error returned during onboarding; omsagent-*x64.sh packages can only be installed on 64-bit systems, and omsagent-*x86.sh packages can only be installed on 32-bit systems; Download the correct package for your architecture from the [latest release](https://github.com/Microsoft/OMS-Agent-for-Linux/releases/latest) |
| 17 | Installation of OMS package failed; Look through the command output for the root failure |
| 19 | Installation of OMI package failed; Look through the command output for the root failure |
| 20 | Installation of SCX package failed; Look through the command output for the root failure |
| 21 | Installation of Provider kits failed; Look through the command output for the root failure |
| 22 | Installation of bundled package failed; Look through the command output for the root failure |
| 23 | SCX or OMI package already installed; Use `--upgrade` instead of `--install` to install the shell bundle |
| 30 | Internal bundle error; File a [GitHub Issue](https://github.com/Microsoft/OMS-Agent-for-Linux/issues) with details from the output |
| 55 | Unsupported openssl version OR Cannot connect to Microsoft OMS service OR dpkg is locked OR Missing curl program |
| 61 | Missing Python ctypes library; Install the Python ctypes library or package (python-ctypes) |
| 62 | Missing tar program; Install tar |
| 63 | Missing sed program; Install sed |
| 64 | Missing curl program; Install curl |
| 65 | Missing gpg program; Install gpg |

## Onboarding Error Codes

| Error Code | Meaning |
| --- | --- |
| 2 | Invalid option provided to the omsadmin script; Run `sudo sh /opt/microsoft/omsagent/bin/omsadmin.sh -h` for usage |
| 3 | Invalid configuration provided to the omsadmin script; Run `sudo sh /opt/microsoft/omsagent/bin/omsadmin.sh -h` for usage |
| 4 | Invalid proxy provided to the omsadmin script; Verify the proxy and see our [documentation for using an HTTP proxy](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/docs/OMS-Agent-for-Linux.md#configuring-the-agent-for-use-with-an-http-proxy-server) |
| 5 | 403 HTTP error received from OMS service; See the full output of the omsadmin script for details |
| 6 | Non-200 HTTP error received from OMS service; See the full output of the omsadmin script for details |
| 7 | Unable to connect to OMS service; See the full output of the omsadmin script for details |
| 8 | Error onboarding to OMS workspace; See the full output of the omsadmin script for details |
| 30 | Internal script error; File a [GitHub Issue](https://github.com/Microsoft/OMS-Agent-for-Linux/issues) with details from the output |
| 31 | Error generating agent ID; File a [GitHub Issue](https://github.com/Microsoft/OMS-Agent-for-Linux/issues) with details from the output |
| 32 | Error generating certificates; See the full output of the omsadmin script for details |
| 33 | Error generating metaconfiguration for omsconfig; File a [GitHub Issue](https://github.com/Microsoft/OMS-Agent-for-Linux/issues) with details from the output |
| 34 | Metaconfiguration generation script not present; Retry onboarding with `sudo sh /opt/microsoft/omsagent/bin/omsadmin.sh -w <OMS Workspace ID> -s <OMS Workspace Key>` |

### Enable Debug Logging
#### OMS output plugin debug
 FluentD allows for plugin specific logging levels allowing you to specify different log levels for inputs and outputs. To specify a different log level for OMS output edit the general agent configuration at `/etc/opt/microsoft/omsagent/<workspace id>/conf/omsagent.conf`:

 In the OMS output plugin, near the bottom of the configuration file, change the `log_level` property from `info` to `debug`

 ```
 <match oms.** docker.**>
  type out_oms
  log_level debug
  num_threads 5
  buffer_chunk_limit 5m
  buffer_type file
  buffer_path /var/opt/microsoft/omsagent/<workspace id>/state/out_oms*.buffer
  buffer_queue_limit 10
  flush_interval 20s
  retry_limit 10
  retry_wait 30s
</match>
 ```

Debug logging allows you to see batched uploads to the OMS Service seperated by type, number of data items, and time taken to send:

*Example debug enabled log:*
```
Success sending oms.nagios x 1 in 0.14s
Success sending oms.omi x 4 in 0.52s
Success sending oms.syslog.authpriv.info x 1 in 0.91s
```

#### Verbose output
Instead of using the OMS output plugin you can also output Data Items directly to `stdout` which is visible in the OMS Agent for Linux log file.

In the OMS general agent configuration file at `/etc/opt/microsoft/omsagent/<workspace id>/conf/omsagent.conf`:

Comment out the OMS output plugin by adding a `#` in front of each line
```
#<match oms.** docker.**>
#  type out_oms
#  log_level info
#  num_threads 5
#  buffer_chunk_limit 5m
#  buffer_type file
#  buffer_path /var/opt/microsoft/omsagent/<workspace id>/state/out_oms*.buffer
#  buffer_queue_limit 10
#  flush_interval 20s
#  retry_limit 10
#  retry_wait 30s
#</match>
```

Below the output plugin, uncomment the following section by removing the `#` in front of each line

```
<match **>
  type stdout
</match>
```

### My forwarded Syslog messages are not showing up!
#### Probable Causes
* The configuration applied to the Linux server does not allow collection of the sent facilities and/or log levels
* Syslog is not being forwarded correctly to the Linux server
* The number of messages being forwarded per second are too great for the base configuration of the OMS Agent for Linux to handle

#### Resolutions
* Check that the configuration in the OMS Portal for Syslog has all the facilities and the correct log levels
  * **OMS Portal > Settings > Data > Syslog**, check also if checkbox **Apply below configuration to my machines** is enabled
* Check that native syslog messaging daemons (`rsyslog`, `syslog-ng`) are able to recieve the forwarded messages
* Check firewall settings on the Syslog server to ensure that messages are not being blocked
* Simulate a Syslog message to OMS using `logger` command
  * `logger -p local0.err "This is my test message"`

### I'm unable to connect through my proxy to OMS
#### Probable Causes
* The proxy specified during onboarding was incorrect
* The OMS Service Endpoints are not whitelistested in your datacenter

#### Resolutions
* Re-onboard to the OMS Service with the OMS Agent for Linux using the following command with the option `-v` enabled. This allows verbose output of the agent connecting through the proxy to the OMS Service.
  * `sudo /opt/microsoft/omsagent/bin/omsadmin.sh -w <OMS Workspace ID> -s <OMS Workspace Key> -p <Proxy Conf> -v`
  * Review documentation for OMS Proxy located [here](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/docs/OMS-Agent-for-Linux.md#configuring-the-agent-for-use-with-an-http-proxy-server)
* Double check that the following OMS Service endpoints are whitelisted

Agent Resource | Ports
---- | ----
*.ods.opinsights.azure.com | Port 443
*.oms.opinsights.azure.com | Port 443
ods.systemcenteradvisor.com | Port 443
*.blob.core.windows.net/ | Port 443

### I'm getting a 403 when I'm trying to onboard!
#### Probable Causes
* Date and Time is incorrect on Linux Server
* Workspace ID and Workspace Key used are not correct

#### Resolution
* Check the time on your Linux server with the command `date`. if the data is +/- 15 minutes from current time then onboarding fails. To correct this update, the date and/or timezone of your Linux server.
 * **New!** The latest version of the OMS Agent for Linux now notifies you if the time skew is causing the onboarding failure
* Re-onboard using correct Workspace ID and Workspace Key [instructions](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/docs/OMS-Agent-for-Linux.md#onboarding-using-the-command-line)

### I'm seeing a 500 Error and 404 Error in the log file right after onboarding
This is a known issue an occurs on first upload of Linux data into an OMS workspace. This does not affect data being sent or service experience.

### I'm getting Errno address already in use in omsagent log file
If you see `[error]: unexpected error error_class=Errno::EADDRINUSE error=#<Errno::EADDRINUSE: Address already in use - bind(2) for "127.0.0.1" port 25224>` in omsagent.log, it would mean that Linux Diagnostic extension (LAD) is installed side by side with OMS linux extension, and it is using same port for syslog data collection as omsagent.
* As root execute the following commands (note that 25224 is an example and it is possible that in your environment you see a different port number used by LAD):
```
/opt/microsoft/omsagent/bin/configure_syslog.sh configure LAD 25229

sed -i -e 's/25224/25229/' /etc/opt/microsoft/omsagent/LAD/conf/omsagent.d/syslog.conf
```
The user will then have to edit the correct rsyslogd or syslog_ng config file and change the LAD-related configuration to write to port 25229.
* If the VM is running rsyslogd, the file to be modified is  `/etc/rsyslog.d/95-omsagent.conf` (if it exists, else `/etc/rsyslog`)
* If the VM is running syslog_ng, the file to be modified is `/etc/syslog-ng/syslog-ng.conf`
* Restart omsagent `sudo /opt/microsoft/omsagent/bin/service_control restart`
* Restart syslog service

### I'm unable to uninstall omsagent using purge option
#### Probable Causes
* Linux diagnostic extension is installed
* Linux diagnostic extension was installed and uninstalled but you still see an error about omsagent being used by mdsd and can not be removed.

#### Resolution
* Uninstall LAD extension.
* Remove LAD files from the machine if they present in the following location: `/var/lib/waagent/Microsoft.Azure.Diagnostics.LinuxDiagnostic-<version>/` and `/var/opt/microsoft/omsagent/LAD/`

### My Nagios data is not showing up in the OMS Portal!
#### Probable Causes
* omsagent user does not have permissions to read from Nagios log file
* Nagios source and filter have not been uncommented from omsagent.conf file

#### Resolutions
* Add omsagent user to read from Nagios file [instructions](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/docs/OMS-Agent-for-Linux.md#nagios-alerts)
* In the OMS Agent for Linux general configuration file at `/etc/opt/microsoft/omsagent/<workspace id>/conf/omsagent.conf` ensure that **both** the Nagios source and filter are uncommented
```
<source>
  type tail
  path /var/log/nagios/nagios.log
  format none
  tag oms.nagios
</source>

<filter oms.nagios>
  type filter_nagios_log
</filter>
```

### I'm not seeing any Linux data in the OMS Portal
#### Probable Causes
* Onboarding to the OMS Service failed
* Connection to the OMS Service is blocked
* VM was rebooted
* OMI package was manually upgraded to a newer version compared to what was installed by OMS Agent package
* DSC resource logs "class not found" error in `omsconfig.log` log file
* OMS Agent for Linux data is backed up
* DSC logs "Current configuration does not exist. Execute Start-DscConfiguration command with -Path parameter to specify a configuration file and create a current configuration first." in `omsconfig.log` log file, but no log message exists about `PerformRequiredConfigurationChecks` operations.

#### Resolutions
* Install all dependencies like auditd package
* Check if onboarding the OMS Service was successful by checking if the following file exists: `/etc/opt/microsoft/omsagent/<workspace id>/conf/omsadmin.conf`
 * Re-onboard using the omsadmin.sh command line [instructions](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/docs/OMS-Agent-for-Linux.md#onboarding-using-the-command-line)
* If using a proxy, check proxy troubleshooting steps above
* In some Azure distribution systems omid OMI server daemon does not start after Virtual machine is rebooted. This will result in not seeing Audit, ChangeTracking or UpdateManagement solution related data. Workaround is manually start omi server by running `sudo /opt/omi/bin/service_control restart`
* After OMI package is manually upgraded to a newer version it has to be manually restarted for OMS Agent to conitnue functioning. This step is required for some distros where OMI server does not automatically start after upgrade. Please run `sudo /opt/omi/bin/service_control restart` to restart OMI.
* If you see DSC resource "class not found" error in omsconfig.log, please run `sudo /opt/omi/bin/service_control restart`
* In some cases, when the OMS Agent for Linux cannot talk to the OMS Service, data on the Agent is backed up to the full buffer size: 50 MB. The OMS Agent for Linux should be restarted by running the following command `/opt/microsoft/omsagent/bin/service_control restart`
 * **Note:** This issue is fixed in Agent version >= 1.1.0-28
* If `omsconfig.log` log file does not indicate that `PerformRequiredConfigurationChecks` operations are running periodically on the system, there might be a problem with the cron job/service. Make sure cron job exists under `/etc/cron.d/OMSConsistencyInvoker`. If needed run the following commands to create the cron job:

```
mkdir -p /etc/cron.d/
echo "*/15 * * * * omsagent /opt/omi/bin/OMSConsistencyInvoker >/dev/null 2>&1" | sudo tee /etc/cron.d/OMSConsistencyInvoker
```

Also, make sure the cron service is running. You can use `service cron status` (Debian, Ubuntu, SUSE) or `service crond status` (RHEL, CentOS, Oracle Linux) to check the status of this service. If the service does not exist, you can install the binaries and start the service using the following:

##### On Ubuntu/Debian:
```
# To Install the service binaries
sudo apt-get install -y cron
# To start the service
sudo service cron start
```

##### On SUSE:
```
# To Install the service binaries
sudo zypper in cron -y
# To start the service
sudo systemctl enable cron
sudo systemctl start cron
```

##### On RHEL/CeonOS:
```
# To Install the service binaries
sudo yum install -y crond
# To start the service
sudo service crond start
```

##### On Oracle Linux:
```
# To Install the service binaries
sudo yum install -y cronie
# To start the service
sudo service crond start
```

### My portal side configuration for (Syslog/Linux Performance Counter) is not being applied
#### Probable Causes
* The OMS Agent for Linux Configuration Agent has not picked up the latest portal side configuration
* The changed settings in the portal were not applied

#### Resolutions
**Background:** `omsconfig` is the OMS Agent for Linux configuration agent that looks for new portal side configuration every 5 minutes. This configuration is then applied to the OMS Agent for Linux configuration files located at /etc/opt/microsoft/omsagent/conf/omsagent.conf.

* In some cases the OMS Agent for Linux configuration agent might not be able to communicate with the portal configuration service resulting in latest configuration not being applied.
 * Check that the `omsconfig` agent is installed
  * `dpkg --list omsconfig` or `rpm -qi omsconfig`
  * If not installed, reinstall the latest version of the OMS Agent for Linux

* Check that the `omsconfig` agent can communicate with the OMS Portal Service
  * Run the following command `sudo su omsagent -c 'python /opt/microsoft/omsconfig/Scripts/GetDscConfiguration.py'`
   * This command returns the Configuration that agent sees from the portal including Syslog settings, Linux Performance Counters, and Custom Logs
   * If this command fails run the following command `sudo su omsagent -c 'python /opt/microsoft/omsconfig/Scripts/PerformRequiredConfigurationChecks.py'`. This command forces the omsconfig agent to talk to the OMS Portal Service and retrieve latest configuration.


### I'm Not Seeing My Custom Log Data in the OMS Portal
#### Probable Causes
* Onboarding to OMS Service failed
* The setting "Apply the following configuration to my Linux Servers" has not been check marked
* omsconfig has not picked up the latest Custom Log from the portal
* OMS Agent for Linux user `omsagent` is unable to access the Custom Log due to permissions or not being found
 * `[DATETIME] [warn]: file not found. Continuing without tailing it.`
 * `[DATETIME] [error]: file not accessible by omsagent.`
* Known Issue with Race Condition fixed in OMS Agent for Linux version 1.1.0-217

#### Resolutions
* Check if onboarding the OMS Service was successful by checking if the following file exists: `/etc/opt/microsoft/omsagent/<workspace id>/conf/omsadmin.conf`
 * Re-onboard using the omsadmin.sh command line [instructions](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/docs/OMS-Agent-for-Linux.md#onboarding-using-the-command-line)
* In the OMS Portal under Settings ensure that the following checkbox is checked ![](pictures/CustomLogLinuxEnabled.png?raw=true)

* Check that the `omsconfig` agent can communicate with the OMS Portal Service
  * Run the following command `sudo su omsagent -c 'python /opt/microsoft/omsconfig/Scripts/GetDscConfiguration.py'`
   * This command returns the Configuration that agent sees from the portal including Syslog settings, Linux Performance Counters, and Custom Logs
   * If this command fails run the following command `sudo su omsagent -c 'python /opt/microsoft/omsconfig/Scripts/PerformRequiredConfigurationChecks.py`. This command forces the omsconfig agent to talk to the OMS Portal Service and retrieve latest configuration.


**Background:** Instead of the OMS Agent for Linux user running as a privileged user, `root` - The OMS Agent for Linux runs as the `omsagent` user. In most cases explicit permission must be granted to this user in order for certain files to be read.
* To grant permission to `omsagent` user run the following commands
 * Add the `omsagent` user to specific group `sudo usermod -a -G <GROUPNAME> <USERNAME>`
 * Grant universal read access to the required file `sudo chmod -R ugo+rx <FILE DIRECTORY>`

* There is a known issue with a Race Condition in OMS Agent for Linux version <1.1.0-217. After updating to the latest agent run the following command to get the latest version of the output plugin
 * `sudo cp /etc/opt/microsoft/omsagent/sysconf/omsagent.conf /etc/opt/microsoft/omsagent/<workspace id>/conf/omsagent.conf`

### I'm re-onboarding to a new workspace
When you try to re-onboard an agent to a new workspace, OMS Agent configuration needs to be cleaned up before re-onboarding. To clean up old configuration from the agent, run the shell bundle with `--purge`

```
sudo sh ./omsagent-*.universal.x64.sh --purge
```
Or

```
sudo sh ./onboard_agent.sh --purge
```

You can continue re-onboarding after using the `--purge` option


### OMS extension on Azure portal is marked as failed state: Provisioning failed
#### Probable Causes
* OMS Agent has been removed on OS side
* OMS Agent service is down/disabled or not configured

#### Resolution (step by step)
* Remove extension from Azure portal
* Install omsagent with [instructions](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-quick-collect-linux-computer)
* On-boarding:
```
 sudo /opt/microsoft/omsagent/bin/omsadmin.sh -w WORKSPACE_ID -s KEY -v
```
* Restart omsagent `sudo /opt/microsoft/omsagent/bin/service_control restart`
* Wait for couple of hours, provisioning state would change to **Provisioning succeeded**


### OMS Agent upgrade on-demand
#### Probable Causes
* OMS packages on the host are outdated

#### Resolution (step by step)
* Check the latest relase on [page](https://github.com/Microsoft/OMS-Agent-for-Linux/releases/)
* Download install script (1.4.2-124 as example version) :
```
wget https://github.com/Microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent_GA_v1.4.2-124/omsagent-1.4.2-124.universal.x64.sh
```
* Upgrade packages by executing `sudo sh ./omsagent-*.universal.x64.sh --upgrade`
