# Configuration for Cisco ASA event collection (Preview)

1. Install and configure the OMS Agent for Linux as described here:  
  * [Documentation for OMS Agent for Linux](https://github.com/Microsoft/OMS-Agent-for-Linux)  
  * [Syslog collection in Operations Management Suite](https://blogs.technet.microsoft.com/msoms/2016/05/12/syslog-collection-in-operations-management-suite/)  

2. Configure Syslog forwarding of Cisco ASA events to the OMS Linux agent machine.

3. Place the following configuration files on the OMS Agent machine:  
	* [security_events.conf](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/mgladi-security-configuration/installer/conf/omsagent.d/security_events.conf)  
	_Fluentd configuration file to enable collection and parsing of Cisco events_  
	Path on Agent machine: ```/etc/opt/microsoft/omsagent/conf/omsagent.d/```  
    
  
  
  * [filter_syslog_security.rb](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/mgladi-security-configuration/source/code/plugins/filter_syslog_security.rb)  
  [security_lib.rb](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/mgladi-security-configuration/source/code/plugins/security_lib.rb)  
  _Fluentd filter plugin that parses the Cisco events_  
  Path on Agent machine: ```/opt/microsoft/omsagent/plugin/```  
  
  
4. Configure Cisco ASA event forwarding to the OMS Agent
  
	*Below is an example configuration for forwarding all events from the local4 facility. You can modify the configuration to fit your local settings.* 
	
	  **If the agent machine has an rsyslog daemon:**  
	  In directory ```/etc/rsyslog.d/```, create new file ```cisco-config-omsagent.conf``` with the following content:
	```
	#OMS_facility = local4
	local4.debug       @127.0.0.1:25225
	```  
	
	
	  **If the agent machine has a syslog-ng daemon:**  
	  In directory ``` /etc/syslog-ng/```, create new file ```cisco-config-omsagent.conf``` with the following content:
	```
	#OMS_facility = local4
	filter f_local4_oms { facility(local4); };
	destination cisco_oms { tcp("127.0.0.1" port(25225)); };
	log { source(src); filter(f_local4_oms); destination(cisco_oms); };
	```

4. Restart the syslog daemon:  
```sudo service rsyslog restart``` or ```systemctl restart omsagent```


5. Restart the OMS agent:  
```sudo service omsagent restart``` or ```/etc/init.d/syslog-ng restart```


6. Confirm that there are no errors in the OMS Agent log:  
```tail /var/opt/microsoft/omsagent/log/omsagent.log```
