# Apache HTTP Server Log Monitoring Solution for Operations Management Suite

1. Set up a supported Linux machine and install an [Apache HTTP Server](http://httpd.apache.org/docs/current/install.html).

2. Download and install [OMS Agent for Linux](https://github.com/Microsoft/OMS-Agent-for-Linux) on the machine.

3. If `/etc/opt/microsoft/omsagent/conf/omsagent.d/apache_logs.conf` is not present, move `apache_logs.conf`:
  ```
  sudo cp /etc/opt/microsoft/omsagent/sysconf/omsagent.d/apache_logs.conf /etc/opt/microsoft/omsagent/conf/omsagent.d/
  sudo chown omsagent:omiusers /etc/opt/microsoft/omsagent/conf/omsagent.d/apache_logs.conf
  ```

4. Specify the machine's log file paths in the configuration file `/etc/opt/microsoft/omsagent/conf/omsagent.d/apache_logs.conf` and comment out the other options with `#`:

  ```
  # Apache Access Log
  <source>
    ...
    path /usr/local/apache2/logs/access_log  #/var/log/apache2/access.log /var/log/httpd/access_log /var/log/apache2/access_log
    ...
  </source>

  # Apache Error Log
  <source>
    ...
    path /usr/local/apache2/logs/error_log  #/var/log/apache2/error.log /var/log/httpd/error_log /var/log/apache2/error_log
    ...
  </source>
  ```

5. Restart the OMS agent:
`sudo service omsagent restart`

6. Confirm that there are no errors in the OMS agent log:
`tail /var/opt/microsoft/omsagent/log/omsagent.log`

  Go to OMS Log Analytics and see whether you can find any search results
  ![ApacheHTTPServerSearchView](pictures/ApacheHTTPServerSearchView.PNG?raw=true)

7. [Collect performance data](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/docs/OMS-Agent-for-Linux.md#enabling-apache-http-server-performance-counters) from an Apache HTTP Server with the OMS agent.
