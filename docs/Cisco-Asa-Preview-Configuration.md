# Configuration for Cisco ASA event collection (Preview)

1. Download the OMS Agent for Linux, version 1.1.0-239 or above:  
	* [OMS Agent For Linux, Public Preview (2016-07)](https://github.com/Microsoft/OMS-Agent-for-Linux/releases/tag/v1.1.0-239)    

2. Install and configure the agent as described here:  
  * [Documentation for OMS Agent for Linux](https://github.com/Microsoft/OMS-Agent-for-Linux)  
  * [Syslog collection in Operations Management Suite](https://blogs.technet.microsoft.com/msoms/2016/05/12/syslog-collection-in-operations-management-suite/)  

3. Configure Syslog forwarding of Cisco ASA events to the OMS Linux agent machine.

4. Place the following configuration file on the OMS Agent machine:  
	* [security_events.conf](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/installer/conf/omsagent.d/security_events.conf)  
	_Fluentd configuration file to enable collection and parsing of Cisco events_  
	Destination path on Agent machine: ```/etc/opt/microsoft/omsagent/<workspace id>/conf/omsagent.d/```  

  
5. Configure Cisco ASA event forwarding to the OMS Agent  
	*The required events need to be forwarded to port 25226 on the agent machine to be collected by the agent.*

	*Below is an example configuration for forwarding all events from the local4 facility. You can modify the configuration to fit your local settings.* 
	
	  **If the agent machine has an rsyslog daemon:**  
	  In directory ```/etc/rsyslog.d/```, create new file ```cisco-config-omsagent.conf``` with the following content:
	```
	#OMS_facility = local4
	local4.debug       @127.0.0.1:25226
	```  
	
	
	  **If the agent machine has a syslog-ng daemon:**  
	  In directory ``` /etc/syslog-ng/```, create new file ```cisco-config-omsagent.conf``` with the following content:
	```
	#OMS_facility = local4
	filter f_local4_oms { facility(local4); };
	destination cisco_oms { tcp("127.0.0.1" port(25226)); };
	log { source(src); filter(f_local4_oms); destination(cisco_oms); };
	```

6. Restart the syslog daemon:  
```sudo service rsyslog restart``` or ```/etc/init.d/syslog-ng restart```


7. Restart the OMS agent:  
```sudo /opt/microsoft/omsagent/bin/service_control restart [<workspace id>]```


8. Confirm that there are no errors in the OMS Agent log:  
```tail /var/opt/microsoft/omsagent/<workspace id>/log/omsagent.log```

9. The events will appear in OMS under the **CommonSecurityLog** type.  
Log search query: ```Type=CommonSecurityLog```
