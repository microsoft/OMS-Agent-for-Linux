### VMware Solution Faq

##### Q.1  What do I need to do on the ESXi Host setting? Customer is asking what impact will I have on my current environment.
A.1  Currently, we use the native ESXi Host Syslog forwarding mechanism. There is no added software from Microsoft on the ESXi Host to capture the logs. This is very low impact to the customer's existing environment. You will need to set the syslog forwarding which is a ESXI functionality. See doc for more information [here.](https://azure.microsoft.com/en-us/documentation/articles/log-analytics-vmware/)

##### Q.2 Do I need to reboot my ESXi Host?
A.2 No. This process does not require a reboot. Sometimes, vSphere UI does not properly update the syslog. In such case, log into ESXi Host and reload the syslog. This again will not require a reboot. So it is not disruptive to your environment.

##### Q.3 Can I increase or lower the volume of the logs pushing into OMS?
A.3 Yes you can. You can use the ESXi Host Log Level settings on vSphere. Our log collection is based on the "info" level. So if you want the VM creation/deletion auditing, you will need to keep the "info" level on Hostd. Please refer to this KB article from VMware.
https://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1017658

##### Q.4 Hostd is not providing data to my OMS. My log setting is set to info.
A.4 There was an ESXi Host bug on the syslog timestamp. Please refer to this KB article from VMware.
Once you've applied the workaround, Hostd will be fine.
https://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2111202

##### Q.5 Can I have more than multiple ESXi Host forwarding syslog data to a single VM with omsagent?
A.5  Yes. You can have multiple ESXi Host forwarding to a single VM with omsagent.

##### Q.6 I do not see data flowing into OMS.
A.6 There can be multiple reasons.
- ESXi Host may not correctly pushing data to the VM with omsagent.
  To test this go can do the following:
	- Check vSphere settings in Advance Configuration. See if it is set correct. See [here.](https://azure.microsoft.com/en-us/documentation/articles/log-analytics-vmware/)
	- Login into ESXi Host via ssh and run the following command.

	```nc -z ipaddressofVM 1514```

	- If it is successful, but you do not see data coming in, try reloading the syslog on ESXi Host via ssh and run the following command.

	```esxcli system syslog reload```

	- Is the port on the OMS agent open on 1514? Login to your VM and run the following command.

	```netstat -a | grep 1514```

	- You should see the port 1514/tcp but if you do not, check whether the omsagent is installed correctly. If you do not see it, there is high chance that the syslog port is not open on the VM.
		- Check ```/etc/opt/microsoft/omsagent/conf/omsagent.d/vmware_esxi.conf``` file is available.
		- Make sure proper user/group setting is done.

		```-rw-r--r-- 1 omsagent omiusers 677 Sep 20 16:46 vmware_esxi.conf```

##### Q.7 How does it capture the logs architecturally?  
We use native syslog function of ESXi Host to push data to the target VM which has OMS Agent. However, we don't write files into syslog within the target VM. OMS agent opens the port 1514 and listens to this. Once it recieved the data, OMS agent will push the data into OMS portal. 
