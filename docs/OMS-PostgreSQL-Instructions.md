# PostgreSQL Log Monitoring Solution for Operations Management Suite

1. Setup a Linux(Ubuntu/Redhat) machine and [install PostgreSQL](https://www.postgresql.org/download/linux/).

2. Download and Install [OMS Agent for Linux](https://github.com/Microsoft/OMS-Agent-for-Linux) on the machine. 

3. Configure PostgreSQL to [generate logs](https://www.postgresql.org/docs/current/static/runtime-config-logging.html).

4. Verify and update the PostgreSQL log file path in the configuration file `/etc/opt/microsoft/omsagent/<workspace id>/conf/omsagent.d/postgresql_logs.conf`

  ```
  <source>
    ...
    path <PostgreSQL-file-path-for-logs>
    ...
  </source>
  ```
  If postgresql_logs.conf is not present in the above location, move it:

  ``` 
  sudo cp /etc/opt/microsoft/omsagent/sysconf/omsagent.d/postgresql_logs.conf /etc/opt/microsoft/omsagent/<workspace id>/conf/omsagent.d/
  sudo chown omsagent:omsagent  /etc/opt/microsoft/omsagent/<workspace id>/conf/omsagent.d/postgresql_logs.conf
  ``` 

5. Restart the PostgreSQL daemon:
`sudo service postgresql restart` or `/etc/init.d/postgresql restart`

6. Restart the OMS agent:
`sudo sh /opt/microsoft/omsagent/bin/service_control restart [<workspace id>]`

7. Confirm that there are no errors in the OMS Agent log:
`tail /var/opt/microsoft/omsagent/<workspace id>/log/omsagent.log`

Go to OMS Log Analytics and see whether you can find any search results
![PostgreSQLSearchView](pictures/PostgeSQLSearchView.png?raw=true)

Supported on ProsgreSQL >= 9 and tested on Ubuntu/RedHat machines.
