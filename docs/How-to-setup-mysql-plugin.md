# How to enable MySQL plugin to collect MySQL server stats and performance data
  - Machine has to have libmysqlclient.so installed (libmysqlclient can be download and installed it through mysql-devel package)

Example for RPM based systems : yum install mysql-devel
    
Example for Debian based systems: apt-get install libmysqlclient-dev
* Install omsagent on the machine
* Install MySQL server on the machine
* Start MySQL server:

   service mysqld start
* Copy mysqlworkload.conf from sysconf to omsagent local path under /conf/omsagent.d/mysqlworkload.conf.
* Restart omsagent:
 
		service omsagent restart


