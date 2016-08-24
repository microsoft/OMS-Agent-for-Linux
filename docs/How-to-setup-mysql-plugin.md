# How to enable MySQL plugin to collect MySQL server stats and performance data
* Install omsagent on the machine
* Install MySQL server on the machine
* Start MySQL server:

   service mysqld start
* Copy mysqlworkload.conf from /etc/opt/microsoft/omsagent/sysconf/omsagent.d/ to /etc/opt/microsoft/omsagent/conf/omsagent.d/.
* Restart omsagent:
 
		service omsagent restart


