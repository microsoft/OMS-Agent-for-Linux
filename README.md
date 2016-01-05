# Operations Management Suite Agent for Linux Public Preview

## Overview
Welcome to the OMS Agent for Linux! The OMS Agent for Linux enables rich and real-time analytics for operational data (Syslog, Performance, Alerts, Inventory) from Linux servers, Docker Containers and monitoring tools like Nagios, Zabbix and System Center.

Our goal for this preview is to get your feedback on onboarding the agent, configuring data to be collected, and your general experience using OMS with Linux data. We rely on your feedback to improve both design and implementation of these features. As this is a preview, the feature set is subject to change.

*Note: the features and supported Linux versions in this Technical Preview are a limited subset of planned capabilities*
## Quick Install guide
Run the following commands to download the omsagent, validate the checksum, and install+onboard the agent. *Commands are for 64-bit*. The Workspace ID and Primary Key can be found inside the OMS Portal under Settings in the **connected sources** tab.
```
$> wget https://github.com/MSFTOSSMgmt/OMS-Agent-for-Linux/releases/download/1.0.0-47/omsagent-1.0.0-47.universal.x64.sh
$> md5sum ./omsagent-1.0.0-47.universal.x64.sh
$> sudo sh ./omsagent-1.0.0-47.universal.x64.sh --upgrade -w <YOUR OMS WORKSPACE ID> -s <YOUR OMS WORKSPACE PRIMARY KEY>
```
[Full installation guide](docs/OMS-Agent-for-Linux.md#install-the-oms-agent-for-linux)

### [Video Walkthrough](https://www.youtube.com/watch?v=7b4KxL7E5fw)

## [Download Latest OMS Agent for Linux (64-bit)](releases/download/1.0.0-47/omsagent-1.0.0-47.universal.x64.sh)
## [Download Latest OMS Agent for Linux (32-bit)](releases/download/1.0.0-47/omsagent-1.0.0-47.universal.x86.sh)
## Feedback

We love feedback!  Whether it be good, bad or indifferent, it really helps us build a better product for you.  There are a few different routes to give feedback:

* **UserVoice:** Post ideas for new OMS features to work on [here](http://feedback.azure.com/forums/267889-azure-operational-insights)
* **Email:** scdata@microsoft.  Tell us whatever is on your mind
* **Monthly survey:** if you are an OMS customer, you know we send out a survey every month asking our customers about the features we’re working on next.  
* **Elite Linux customer panel:** If you are a die-hard OMS Linux user and want to join our weekly calls and talk directly to the product team apply through this **[survey](https://www.surveymonkey.com/r/6MTHN3P).**

## Supported Linux Operating Systems
* Amazon Linux 2012.09 --> 2015.09 (x86/x64)
* CentOS Linux 5,6, and 7 (x86/x64)
* Oracle Linux 5,6, and 7 (x86/x64)
* Red Hat Enterprise Linux Server 5,6 and 7 (x86/x64)
* Debian GNU/Linux 6, 7, and 8 (x86/x64)
* Ubuntu 12.04 LTS, 14.04 LTS, 15.04 (x86/x64)
* SUSE Linux Enteprise Server 11 and 12 (x86/x64)

## Supported Scenarios
### [Syslog data collection](docs/OMS-Agent-for-Linux.md#viewing-syslog-events)
### [Docker collection](docs/Docker-Instructions.md)
### [Performance data collection](docs/OMS-Agent-for-Linux.md#viewing-performance-data)
### [Nagios Core alert collection](docs/OMS-Agent-for-Linux.md#viewing-nagios-alerts)
### [Zabbix alert collection](docs/OMS-Agent-for-Linux.md#viewing-zabbix-alerts)

## [Full documentation](docs/OMS-Agent-for-Linux.md)
