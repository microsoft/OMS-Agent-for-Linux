# Operations Management Suite Agent for Linux (2016-08)

## Overview
Welcome to the OMS Agent for Linux! The OMS Agent for Linux enables rich and real-time analytics for operational data (Syslog, Performance, Alerts, Inventory) from Linux servers, Docker Containers and monitoring tools like Nagios, Zabbix and System Center.

## Quick Install guide
Run the following commands to download the omsagent, validate the checksum, and install+onboard the agent. *Commands are for 64-bit*. The Workspace ID and Primary Key can be found inside the OMS Portal under Settings in the **connected sources** tab.
```
$> wget https://github.com/Microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent_Ignite2016_v1.2.0-75/omsagent-1.2.0-75.universal.x64.sh 
$> sha256sum ./omsagent-1.2.0-75.universal.x64.sh
$> sudo sh ./omsagent-1.2.0-75.universal.x64.sh --upgrade -w <YOUR OMS WORKSPACE ID> -s <YOUR OMS WORKSPACE PRIMARY KEY>
```
## Azure Install guide
If you are an Azure customer, we have an Azure VM Extension that allows you to onboard with a couple of clicks.
* [OMS Agent for Linux Azure VM Extension Documentation](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/docs/VM-Extension.md)
* [Azure Video walkthrough](https://www.youtube.com/watch?v=mF1wtHPEzT0)

## [Full installation guide](docs/OMS-Agent-for-Linux.md#install-the-oms-agent-for-linux)

### [Video Walkthrough](https://www.youtube.com/watch?v=7b4KxL7E5fw)

## [Download Latest OMS Agent for Linux (64-bit)](https://github.com/Microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent_GA_v1.2.0-25/omsagent-1.2.0-25.universal.x64.sh)
## [Download Latest OMS Agent for Linux (32-bit)](https://github.com/Microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent_GA_v1.2.0-25/omsagent-1.2.0-25.universal.x86.sh)
## Feedback

We love feedback!  Whether it be good, bad or indifferent, it really helps us build a better product for you.  There are a few different routes to give feedback:

* **UserVoice:** Post ideas for new OMS features to work on [here](http://feedback.azure.com/forums/267889-azure-operational-insights)
* **Monthly survey:** if you are an OMS customer, you know we send out a survey every month asking our customers about the features we’re working on next.  
* **Elite Linux customer panel:** If you are a die-hard OMS Linux user and want to join our weekly calls and talk directly to the product team apply through this **[survey](https://www.surveymonkey.com/r/6MTHN3P).**

## Supported Linux Operating Systems
* Amazon Linux 2012.09 --> 2015.09 (x86/x64)
* CentOS Linux 5,6, and 7 (x86/x64)
* Oracle Linux 5,6, and 7 (x86/x64)
* Red Hat Enterprise Linux Server 5,6 and 7 (x86/x64)
* Debian GNU/Linux 6, 7, and 8 (x86/x64)
* Ubuntu 12.04 LTS, 14.04 LTS, 15.04, 15.10, 16.04 LTS (x86/x64)
* SUSE Linux Enteprise Server 11 and 12 (x86/x64)

## Supported Scenarios
### [Syslog data collection](docs/OMS-Agent-for-Linux.md#viewing-syslog-events)
### [Docker collection](docs/Docker-Instructions.md)
### [Performance data collection](docs/OMS-Agent-for-Linux.md#viewing-performance-data)
### [Nagios Core alert collection](docs/OMS-Agent-for-Linux.md#viewing-nagios-alerts)
### [Zabbix alert collection](docs/OMS-Agent-for-Linux.md#viewing-zabbix-alerts)
### [CollectD Metrics Collection](docs/OMS-Agent-for-Linux.md#collectd-metrics)
### [Custom JSON Data](docs/OMS-Agent-for-Linux.md#custom-json-data-sources)
### [VMware Monitoring] (docs/VMware-Instruction.md)
## [Full documentation](docs/OMS-Agent-for-Linux.md)

## [Troubleshooting Guide](docs/Troubleshooting.md)
