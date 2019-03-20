"""Test OMS Agent bundle functionality within a container."""

import datetime
import os
import os.path
import subprocess
import re
import sys
import time

if "check_output" not in dir(subprocess): # duck punch it in!
    def check_output(*popenargs, **kwargs):
        r"""Run command with arguments and return its output as a byte string.
        Backported from Python 2.7 as it's implemented as pure python on stdlib.
        >>> check_output(['/usr/bin/python', '--version'])
        Python 2.6.2
        """
        process = subprocess.Popen(stdout=subprocess.PIPE, *popenargs, **kwargs)
        output, unused_err = process.communicate()
        retcode = process.poll()
        if retcode:
            cmd = kwargs.get("args")
            if cmd is None:
                cmd = popenargs[0]
            error = subprocess.CalledProcessError(retcode, cmd)
            error.output = output
            raise error
        return output

    subprocess.check_output = check_output

operation = None

outFile = '/home/temp/omsresults.out'
openFile = open(outFile, 'w+')

def linux_detect_installer():
    """Check what installer (dpkg or rpm) should be used."""
    global INSTALLER
    INSTALLER = None
    if os.system("which dpkg > /dev/null 2>&1") == 0:
        INSTALLER = "DPKG"
    elif os.system("which rpm > /dev/null 2>&1") == 0:
        INSTALLER = "RPM"

def main():
    """Determine the operation to executed, and execute it."""
    linux_detect_installer()

    global operation
    try:
        option = sys.argv[1]
        if re.match('^([-/]*)(preinstall)', option):
            set_hostname()
            start_system_services()
            install_additional_packages()
        elif re.match('^([-/]*)(postinstall)', option):
            detect_workspace_id()
            config_start_oms_services()
            restart_services()
        elif re.match('^([-/]*)(status)', option):
            result_commands()
            service_control_commands()
            write_html()
        elif re.match('^([-/]*)(copyomslogs)', option):
            detect_workspace_id()
            copy_oms_logs()
        elif re.match('^([-/]*)(injectlogs)', option):
            inject_logs()
    except:
        if operation is None:
            print("No operation specified. run with 'preinstall', 'postinstall', 'status', or 'injectlogs'")

def replace_items(infile, old_word, new_word):
    """Replace old_word with new_world in file infile."""
    if not os.path.isfile(infile):
        print("Error on replace_word, not a regular file: " + infile)
        sys.exit(1)

    f1 = open(infile, 'r').read()
    f2 = open(infile, 'w')
    m = f1.replace(old_word,new_word)
    f2.write(m)

def append_file(src, dest):
    """Append contents of src to dest."""
    f = open(src, 'r')
    dest.write(f.read())
    f.close()

def detect_workspace_id():
    """Detect the workspace id where the agent is onboarded."""
    global workspace_id
    x = subprocess.check_output('/opt/microsoft/omsagent/bin/omsadmin.sh -l', shell=True)
    try:
        workspace_id = re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x).group(0)
    except AttributeError:
        workspace_id = None

def set_hostname():
    """Set /etc/hostname and modify /etc/hosts to prevent getaddrinfo failure."""
    hostname = os.popen('hostname').read()[:-1] # strip \n
    os.system(r"sed '$s|\(.*\)\t.*|\1\t{0}|' /etc/hosts > /etc/_hosts".format(hostname))
    os.system('echo {0} > /etc/hostname \
            && cat /etc/_hosts > /etc/hosts \
            && rm /etc/_hosts'.format(hostname))

def start_system_services():
    """Start rsyslog, cron and apache to enable log collection."""
    os.system('service rsyslog start')
    if INSTALLER == 'DPKG':
        os.system('cron \
                && service apache2 start')
    elif INSTALLER == 'RPM':
        os.system('service crond start \
                && service httpd start')

def install_additional_packages():
    """Install additional packages as needed."""
    if INSTALLER == 'DPKG':
        os.system('apt-get -y update')
    elif INSTALLER == 'RPM':
        os.system('yum -y update')

def disable_dsc():
    """Disable DSC so that agent can be manually configured."""
    os.system('/opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py --disable')
    pending_mof = '/etc/opt/omi/conf/omsconfig/configuration/Pending.mof'
    current_mof = '/etc/opt/omi/conf/omsconfig/configuration/Pending.mof'
    if os.path.isfile(pending_mof) or os.path.isfile(current_mof):
        os.remove(pending_mof)
        os.remove(current_mof)

def copy_config_files():
    """Convert, copy, and set permissions for agent configuration files."""
    os.system('dos2unix /home/temp/omsfiles/perf.conf \
            && dos2unix /home/temp/omsfiles/rsyslog-oms.conf \
            && cat /home/temp/omsfiles/perf.conf >> /etc/opt/microsoft/omsagent/{0}/conf/omsagent.conf \
            && cp /home/temp/omsfiles/rsyslog-oms.conf /etc/opt/omi/conf/omsconfig/rsyslog-oms.conf \
            && cp /home/temp/omsfiles/rsyslog-oms.conf /etc/rsyslog.d/95-omsagent.conf \
            && chown omsagent:omiusers /etc/rsyslog.d/95-omsagent.conf \
            && chmod 644 /etc/rsyslog.d/95-omsagent.conf \
            && cp /home/temp/omsfiles/customlog.conf /etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/customlog.conf \
            && chown omsagent:omiusers /etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/customlog.conf \
            && cp /etc/opt/microsoft/omsagent/sysconf/omsagent.d/apache_logs.conf /etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/apache_logs.conf \
            && cp /etc/opt/microsoft/omsagent/sysconf/omsagent.d/mysql_logs.conf /etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/mysql_logs.conf'.format(workspace_id))
    replace_items('/etc/opt/microsoft/omsagent/{0}/conf/omsagent.conf'.format(workspace_id), '<workspace-id>', workspace_id)
    replace_items('/etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/customlog.conf'.format(workspace_id), '<workspace-id>', workspace_id)

def apache_mysql_conf():
    """Configure Apache and MySQL, set up empty log files, and add permissions."""
    apache_conf_file = '/etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/apache_logs.conf'.format(workspace_id)
    mysql_conf_file = '/etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/mysql_logs.conf'.format(workspace_id)
    apache_access_conf_path_string = '/usr/local/apache2/logs/access_log /var/log/apache2/access.log /var/log/httpd/access_log /var/log/apache2/access_log'
    apache_error_conf_path_string = '/usr/local/apache2/logs/error_log /var/log/apache2/error.log /var/log/httpd/error_log /var/log/apache2/error_log'
    os.system('chown omsagent:omiusers {0}'.format(apache_conf_file))
    os.system('chown omsagent:omiusers {0}'.format(mysql_conf_file))

    os.system('mkdir -p /var/log/mysql \
            && touch /var/log/mysql/mysql.log /var/log/mysql/error.log /var/log/mysql/mysql-slow.log \
            && touch /var/log/custom.log \
            && chmod +r /var/log/mysql/* \
            && chmod +rx /var/log/mysql \
            && chmod +r /var/log/custom.log')

    if INSTALLER == 'DPKG':
        replace_items(apache_conf_file, apache_access_conf_path_string, '/var/log/apache2/access.log')
        replace_items(apache_conf_file, apache_error_conf_path_string, '/var/log/apache2/error.log')
        os.system('mkdir -p /var/log/apache2 \
                && touch /var/log/apache2/access.log /var/log/apache2/error.log \
                && chmod +r /var/log/apache2/* \
                && chmod +rx /var/log/apache2')
    elif INSTALLER == 'RPM':
        replace_items(apache_conf_file, apache_access_conf_path_string, '/var/log/httpd/access_log')
        replace_items(apache_conf_file, apache_error_conf_path_string, '/var/log/httpd/error_log')
        os.system('mkdir -p /var/log/httpd \
                && touch /var/log/httpd/access_log /var/log/httpd/error_log \
                && chmod +r /var/log/httpd/* \
                && chmod +rx /var/log/httpd')

def inject_logs():
    """Inject logs (after) agent is running in order to simulate real Apache/MySQL/Custom logs output."""

    # set apache timestamps to current time to ensure they are searchable with 1 hour period in log analytics
    now = datetime.datetime.utcnow().strftime('[%d/%b/%Y:%H:%M:%S +0000]')
    os.system(r"sed -i 's|\(\[.*\]\)|{0}|' /home/temp/omsfiles/apache_access.log".format(now))

    if INSTALLER == 'DPKG':
        os.system('cat /home/temp/omsfiles/apache_access.log >> /var/log/apache2/access.log \
                && chown root:root /var/log/apache2/access.log \
                && chmod 644 /var/log/apache2/access.log \
                && dos2unix /var/log/apache2/access.log')
    elif INSTALLER == 'RPM':
        os.system('cat /home/temp/omsfiles/apache_access.log >> /var/log/httpd/access_log \
                && chown root:root /var/log/httpd/access_log \
                && chmod 644 /var/log/httpd/access_log \
                && dos2unix /var/log/httpd/access_log')

    os.system('cat /home/temp/omsfiles/mysql.log >> /var/log/mysql/mysql.log \
            && cat /home/temp/omsfiles/error.log >> /var/log/mysql/error.log \
            && cat /home/temp/omsfiles/mysql-slow.log >> /var/log/mysql/mysql-slow.log \
            && cat /home/temp/omsfiles/custom.log >> /var/log/custom.log')


def config_start_oms_services():
    """Orchestrate overall configuration prior to agent start."""
    os.system('/opt/omi/bin/omiserver -d')
    disable_dsc()
    copy_config_files()
    apache_mysql_conf()

def restart_services():
    """Restart rsyslog, OMI, and OMS."""
    time.sleep(10)
    os.system('service rsyslog restart \
            && /opt/omi/bin/service_control restart \
            && /opt/microsoft/omsagent/bin/service_control restart')

def exec_command(cmd):
    """Run the provided command, check, and return its output."""
    try:
        out = subprocess.check_output(cmd, shell=True)
        return out
    except subprocess.CalledProcessError as e:
        print(e.returncode)
        return e.returncode

def write_log_output(out):
    """Save command output to the log file."""
    if(type(out) != str):
        out = str(out)
    openFile.write(out + '\n')
    openFile.write('-' * 80)
    openFile.write('\n')

def write_log_command(cmd):
    """Print command and save command to log file."""
    print(cmd)
    openFile.write(cmd + '\n')
    openFile.write('=' * 40)
    openFile.write('\n')

def check_pkg_status(pkg):
    """Check pkg install status and return output and derived status."""
    if INSTALLER == 'DPKG':
        cmd = 'dpkg -s {0}'.format(pkg)
        output = exec_command(cmd)
        if (os.system('{0} | grep deinstall > /dev/null 2>&1'.format(cmd)) == 0 or
                os.system('dpkg -s omsagent > /dev/null 2>&1') != 0):
            status = 'Not Installed'
        else:
            status = 'Install Ok'
    elif INSTALLER == 'RPM':
        cmd = 'rpm -qi {0}'.format(pkg)
        output = exec_command(cmd)
        if os.system('{0} > /dev/null 2>&1'.format(cmd)) == 0:
            status = 'Install Ok'
        else:
            status = 'Not Installed'

    write_log_command(cmd)
    write_log_output(output)
    return (output, status)

def result_commands():
    """Determine and store status of agent."""
    global onboardStatus, omiRunStatus, psefomsagent, omsagentRestart, omiRestart
    global omiInstallOut, omsagentInstallOut, omsconfigInstallOut, scxInstallOut, omiInstallStatus, omsagentInstallStatus, omsconfigInstallStatus, scxInstallStatus
    cmd = '/opt/microsoft/omsagent/bin/omsadmin.sh -l'
    onboardStatus = exec_command(cmd)
    write_log_command(cmd)
    write_log_output(onboardStatus)
    cmd = 'scxadmin -status'
    omiRunStatus = exec_command(cmd)
    write_log_command(cmd)
    write_log_output(omiRunStatus)

    omiInstallOut, omiInstallStatus = check_pkg_status('omi')
    omsagentInstallOut, omsagentInstallStatus = check_pkg_status('omsagent')
    omsconfigInstallOut, omsconfigInstallStatus = check_pkg_status('omsconfig')
    scxInstallOut, scxInstallStatus = check_pkg_status('scx')

    # OMS agent process check
    cmd = 'ps -ef | egrep "omsagent|omi"'
    psefomsagent = exec_command(cmd)
    write_log_command(cmd)
    write_log_output(psefomsagent)

    time.sleep(10)
    # OMS agent restart
    cmd = '/opt/microsoft/omsagent/bin/service_control restart'
    omsagentRestart = exec_command(cmd)
    write_log_command(cmd)
    write_log_output(omsagentRestart)

    # OMI agent restart
    cmd = '/opt/omi/bin/service_control restart'
    omiRestart = exec_command(cmd)
    write_log_command(cmd)
    write_log_output(omiRestart)

def service_control_commands():
    """Determine and store results of various service commands."""
    global serviceStop, serviceDisable, serviceEnable, serviceStart

    # OMS stop (shutdown the agent)
    cmd = '/opt/microsoft/omsagent/bin/service_control stop'
    serviceStop = exec_command(cmd)
    write_log_command(cmd)
    write_log_output(serviceStop)

    # OMS disable (disable agent from starting upon system start)
    cmd = '/opt/microsoft/omsagent/bin/service_control disable'
    serviceDisable = exec_command(cmd)
    write_log_command(cmd)
    write_log_output(serviceDisable)

    # OMS enable (enable agent to start upon system start)
    cmd = '/opt/microsoft/omsagent/bin/service_control enable'
    serviceEnable = exec_command(cmd)
    write_log_command(cmd)
    write_log_output(serviceEnable)

    # OMS start (start the agent)
    cmd = '/opt/microsoft/omsagent/bin/service_control start'
    serviceStart = exec_command(cmd)
    write_log_command(cmd)
    write_log_output(serviceStart)

def write_html():
    """Use stored command results to create an HTML report of the test results."""
    os.system('rm -f /home/temp/omsresults.html')
    html_file = '/home/temp/omsresults.html'
    f = open(html_file, 'w+')

    message = """
<div class="text" style="white-space: pre-wrap" >

<table>
  <caption><h4>OMS Install Results</h4><caption>
  <tr>
    <th>Package</th>
    <th>Status</th>
    <th>Output</th>
  </tr>
  <tr>
    <td>OMI</td>
    <td>{0}</td>
    <td>{1}</td>
  </tr>
  <tr>
    <td>OMSAgent</td>
    <td>{2}</td>
    <td>{3}</td>
  </tr>
  <tr>
    <td>OMSConfig</td>
    <td>{4}</td>
    <td>{5}</td>
  </tr>
  <tr>
    <td>SCX</td>
    <td>{6}</td>
    <td>{7}</td>
  </tr>
</table>

<table>
  <caption><h4>OMS Command Outputs</h4><caption>
  <tr>
    <th>Command</th>
    <th>Output</th>
  </tr>
  <tr>
    <td>/opt/microsoft/omsagent/bin/omsadmin.sh -l</td>
    <td>{8}</td>
  </tr>
  <tr>
    <td>scxadmin -status</td>
    <td>{9}</td>
  </tr>
  <tr>
    <td>ps -ef | egrep "omsagent|omi"</td>
    <td>{10}</td>
  </tr>
  <tr>
    <td>/opt/microsoft/omsagent/bin/service_control restart</td>
    <td>{11}</td>
  <tr>
  <tr>
    <td>/opt/omi/bin/service_control restart</td>
    <td>{12}</td>
  <tr>
  <tr>
    <td>/opt/microsoft/omsagent/bin/service_control stop</td>
    <td>{13}</td>
  <tr>
  <tr>
    <td>/opt/microsoft/omsagent/bin/service_control disable</td>
    <td>{14}</td>
  <tr>
  <tr>
    <td>/opt/microsoft/omsagent/bin/service_control enable</td>
    <td>{15}</td>
  <tr>
  <tr>
    <td>/opt/microsoft/omsagent/bin/service_control stop</td>
    <td>{16}</td>
  <tr>
</table>
</div>
""".format(omiInstallStatus, omiInstallOut, omsagentInstallStatus, omsagentInstallOut, omsconfigInstallStatus, omsconfigInstallOut, scxInstallStatus, scxInstallOut,
           onboardStatus, omiRunStatus, psefomsagent, omsagentRestart, omiRestart, serviceStop, serviceDisable, serviceEnable, serviceStart)

    f.write(message)
    f.close()

def copy_oms_logs():
    omslogfile = "/home/temp/copyofomsagent.log"
    omslogfileOpen = open(omslogfile, 'w+')
    omsagent_file = '/var/opt/microsoft/omsagent/{0}/log/omsagent.log'.format(workspace_id)
    append_file(omsagent_file, omslogfileOpen)

if __name__ == '__main__':
    main()
