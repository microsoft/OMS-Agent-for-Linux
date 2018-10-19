import os
import os.path
import subprocess
import re
import sys

if "check_output" not in dir( subprocess ): # duck punch it in!
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
    global INSTALLER
    INSTALLER=None
    if os.system("which dpkg > /dev/null 2>&1") == 0:
        INSTALLER="DPKG"
    elif os.system("which rpm > /dev/null 2>&1") == 0:
        INSTALLER="RPM"

linux_detect_installer()

def main():
    # Determine the operation being executed
    global operation
    try:
        option = sys.argv[1]
        if re.match('^([-/]*)(preinstall)', option):
            operation = 'preinstall'
        elif re.match('^([-/]*)(postinstall)', option):
            operation = 'postinstall'
        elif re.match('^([-/]*)(status)', option):
            operation = 'status'
    except:
        if operation is None:
            print "No operation specified. run with 'preinstall' or 'postinstall' or 'status'"

    run_operation()

def replace_items(infile, old_word, new_word):
    if not os.path.isfile(infile):
        print("Error on replace_word, not a regular file: " + infile)
        sys.exit(1)

    f1 = open(infile, 'r').read()
    f2 = open(infile, 'w')
    m = f1.replace(old_word,new_word)
    f2.write(m)

def detect_workspace_id():
    global workspace_id
    x = subprocess.check_output('/opt/microsoft/omsagent/bin/omsadmin.sh -l', shell=True)
    try:
        workspace_id = re.search('[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', x).group(0)
    except AttributeError:
        workspace_id = None

def install_additional_packages():
    #Add additional packages command here
    if INSTALLER == 'DPKG':
        os.system('apt-get -y update')
    elif INSTALLER == 'RPM':
        os.system('yum -y update')

def disable_dsc():
    os.system('/opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py --disable')
    Pending_mof = '/etc/opt/omi/conf/omsconfig/configuration/Pending.mof'
    Current_mof = '/etc/opt/omi/conf/omsconfig/configuration/Pending.mof'
    if os.path.isfile(Pending_mof) or os.path.isfile(Current_mof):
        os.remove(Pending_mof)
        os.remove(Current_mof)

def copy_config_files():
    os.system('dos2unix /home/temp/omsfiles/perf.conf \
            && dos2unix /home/temp/omsfiles/rsyslog-oms.conf \
            && cat /home/temp/omsfiles/perf.conf >> /etc/opt/microsoft/omsagent/{0}/conf/omsagent.conf \
            && cp /home/temp/omsfiles/rsyslog-oms.conf /etc/opt/omi/conf/omsconfig/rsyslog-oms.conf \
            && cp /home/temp/omsfiles/rsyslog-oms.conf /etc/rsyslog.d/95-omsagent.conf \
            && chown omsagent:omiusers /etc/rsyslog.d/95-omsagent.conf \
            && chmod 644 /etc/rsyslog.d/95-omsagent.conf \
            && cp /home/temp/omsfiles/customlog.conf /etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/customlog.conf \
            && chown omsagent:omiusers /etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/customlog.conf \
            && chmod 644 /etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/customlog.conf \
            && cp /etc/opt/microsoft/omsagent/sysconf/omsagent.d/apache_logs.conf /etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/apache_logs.conf \
            && cp /etc/opt/microsoft/omsagent/sysconf/omsagent.d/mysql_logs.conf /etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/mysql_logs.conf'.format(workspace_id))
    replace_items('/etc/opt/microsoft/omsagent/{0}/conf/omsagent.conf'.format(workspace_id), '<workspace-id>', workspace_id)
    replace_items('/etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/customlog.conf'.format(workspace_id), '<workspace-id>', workspace_id)

def apache_mysql_conf():
    apache_conf_dir = '/etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/apache_logs.conf'.format(workspace_id)
    mysql_conf_dir = '/etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/mysql_logs.conf'.format(workspace_id)
    apache_access_conf_path_string = '/usr/local/apache2/logs/access_log /var/log/apache2/access.log /var/log/httpd/access_log /var/log/apache2/access_log'
    apache_error_conf_path_string = '/usr/local/apache2/logs/error_log /var/log/apache2/error.log /var/log/httpd/error_log /var/log/apache2/error_log'
    os.system('chown omsagent:omiusers {0}'.format(apache_conf_dir))
    os.system('chown omsagent:omiusers {0}'.format(mysql_conf_dir))

    os.system('mkdir -p /var/log/mysql \
                && touch /var/log/mysql/mysql.log /var/log/mysql/error.log /var/log/mysql/mysql-slow.log \
                && chmod +r /var/log/mysql/* && chmod +rx /var/log/mysql')

    if INSTALLER == 'DPKG':
        replace_items(apache_conf_dir, apache_access_conf_path_string, '/var/log/apache2/access.log')
        replace_items(apache_conf_dir, apache_error_conf_path_string, '/var/log/apache2/error.log')
        os.system('chmod +r /var/log/apache2/* && chmod +rx /var/log/apache2')
    elif INSTALLER == 'RPM':
        replace_items(apache_conf_dir, apache_access_conf_path_string, '/var/log/httpd/access_log')
        replace_items(apache_conf_dir, apache_error_conf_path_string, '/var/log/httpd/error_log')
        os.system('chmod +r /var/log/httpd/* && chmod +rx /var/log/httpd')

def inject_logs():
    if INSTALLER == 'DPKG':
        os.system('cp /home/temp/omsfiles/apache_access.log /var/log/apache2/access.log')
    elif INSTALLER == 'RPM':
        os.system('cp /home/temp/omsfiles/apache_access.log /var/log/httpd/access_log')

    os.system('cp /home/temp/omsfiles/mysql.log /var/log/mysql/mysql.log \
                && cp /home/temp/omsfiles/error.log /var/log/mysql/error.log \
                && cp /home/temp/omsfiles/mysql-slow.log /var/log/mysql/mysql-slow.log \
                && cp /home/temp/omsfiles/custom.log /var/log/custom.log')

def start_system_services():
    os.system('service rsyslog start')
    if INSTALLER == 'DPKG':
        os.system('service cron start \
                    && service apache2 start')
    elif INSTALLER == 'RPM':
        os.system('service crond start \
                    && service httpd start')

def config_start_oms_services():
    os.system('/opt/omi/bin/omiserver -d')
    disable_dsc()
    copy_config_files()
    apache_mysql_conf()
    inject_logs()

def restart_services():
    os.system('service rsyslog restart \
                &&/opt/omi/bin/service_control restart \
                && /opt/microsoft/omsagent/bin/service_control restart')

'''
Common logic to run any command and check/get its output for further use
'''
def execCommand(cmd):
    try:
        out = subprocess.check_output(cmd, shell=True)
        return out
    except subprocess.CalledProcessError as e:
        print(e.returncode)
        return (e.returncode)

'''
Common logic to save command outputs
'''
def writeLogOutput(out):
    if(type(out) != str): out=str(out)
    openFile.write(out + '\n')
    openFile.write('-' * 80)
    openFile.write('\n')
    return

'''
Common logic to save command itself
'''
def writeLogCommand(cmd):
    print(cmd)
    openFile.write(cmd + '\n')
    openFile.write('=' * 40)
    openFile.write('\n')
    return

def result_commands():
    global onboardStatus, omiRunStatus, psefomsagent, omsagentRestart, omiRestart
    global omiInstallOut, omsagentInstallOut, omsconfigInstallOut, scxInstallOut, omiInstallStatus, omsagentInstallStatus, omsconfigInstallStatus, scxInstallStatus
    cmd='/opt/microsoft/omsagent/bin/omsadmin.sh -l'
    onboardStatus=execCommand(cmd)
    writeLogCommand(cmd)
    writeLogOutput(onboardStatus)
    cmd='scxadmin -status'
    omiRunStatus=execCommand(cmd)
    writeLogCommand(cmd)
    writeLogOutput(omiRunStatus)
    if INSTALLER == 'DPKG':
        cmd='apt show omi'
        omiInstallOut=execCommand(cmd)
        if os.system('dpkg -s omi | grep deinstall > /dev/null 2>&1') == 0 or os.system('dpkg -s omsagent > /dev/null 2>&1') != 0:
            omiInstallStatus='Not Installed'
        else:
            omiInstallStatus='Install Ok'
        writeLogCommand(cmd)
        writeLogOutput(omiInstallOut)
        cmd='apt show omsagent'
        omsagentInstallOut=execCommand(cmd)
        if os.system('dpkg -s omsagent | grep deinstall > /dev/null 2>&1') == 0 or os.system('dpkg -s omsagent > /dev/null 2>&1') != 0:
            omsagentInstallStatus='Not Installed'
        else:
            omsagentInstallStatus='Install Ok'
        writeLogCommand(cmd)
        writeLogOutput(omsagentInstallOut)
        cmd='apt show omsconfig'
        omsconfigInstallOut=execCommand(cmd)
        if os.system('dpkg -s omsconfig | grep deinstall > /dev/null 2>&1') == 0 or os.system('dpkg -s omsagent > /dev/null 2>&1') != 0:
            omsconfigInstallStatus='Not Installed'
        else:
            omsconfigInstallStatus='Install Ok'
        writeLogCommand(cmd)
        writeLogOutput(omsconfigInstallOut)
        cmd='apt show scx'
        scxInstallOut=execCommand(cmd)
        if os.system('dpkg -s scx | grep deinstall > /dev/null 2>&1') == 0 or os.system('dpkg -s omsagent > /dev/null 2>&1') != 0:
            scxInstallStatus=' Not Installed'
        else:
            scxInstallStatus='Install Ok'
        writeLogCommand(cmd)
        writeLogOutput(scxInstallOut)
    elif INSTALLER == 'RPM':
        cmd='rpm -qi omi'
        omiInstallOut=execCommand(cmd)
        if os.system('{0} > /dev/null 2>&1'.format(cmd)) == 0:
            omiInstallStatus='Install Ok'
        else:
            omiInstallStatus='Not Installed'
        writeLogCommand(cmd)
        writeLogOutput(omiInstallOut)
        cmd='rpm -qi omsagent'
        omsagentInstallOut=execCommand(cmd)
        if os.system('{0} > /dev/null 2>&1'.format(cmd)) == 0:
            omsagentInstallStatus='Install Ok'
        else:
            omsagentInstallStatus='Not Installed'
        writeLogCommand(cmd)
        writeLogOutput(omsagentInstallOut)
        cmd='rpm -qi omsconfig'
        omsconfigInstallOut=execCommand(cmd)
        if os.system('{0} > /dev/null 2>&1'.format(cmd)) == 0:
            omsconfigInstallStatus='Install Ok'
        else:
            omsconfigInstallStatus='Not Installed'
        writeLogCommand(cmd)
        writeLogOutput(omsconfigInstallOut)
        cmd='rpm -qi scx'
        scxInstallOut=execCommand(cmd)
        if os.system('{0} > /dev/null 2>&1'.format(cmd)) == 0:
            scxInstallStatus='Install Ok'
        else:
            scxInstallStatus='Not Installed'
        writeLogCommand(cmd)
        writeLogOutput(scxInstallOut)
    cmd='ps -ef | egrep "omsagent|omi"'
    psefomsagent=execCommand(cmd)
    writeLogCommand(cmd)
    writeLogOutput(psefomsagent)
    cmd='/opt/microsoft/omsagent/bin/service_control restart'
    omsagentRestart=execCommand(cmd)
    writeLogCommand(cmd)
    writeLogOutput(omsagentRestart)
    cmd='/opt/omi/bin/service_control restart'
    omiRestart=execCommand(cmd)
    writeLogCommand(cmd)
    writeLogOutput(omiRestart)

def service_control_commands():
    global serviceStop, serviceDisable, serviceEnable, serviceStart
    cmd='/opt/microsoft/omsagent/bin/service_control stop'
    serviceStop=execCommand(cmd)
    writeLogCommand(cmd)
    writeLogOutput(serviceStop)
    cmd='/opt/microsoft/omsagent/bin/service_control disable'
    serviceDisable=execCommand(cmd)
    writeLogCommand(cmd)
    writeLogOutput(serviceDisable)
    cmd='/opt/microsoft/omsagent/bin/service_control enable'
    serviceEnable=execCommand(cmd)
    writeLogCommand(cmd)
    writeLogOutput(serviceEnable)
    cmd='/opt/microsoft/omsagent/bin/service_control start'
    serviceStart=execCommand(cmd)
    writeLogCommand(cmd)
    writeLogOutput(serviceStart)

def write_html():
    os.system('rm /home/temp/omsresults.html')
    htmlFile = '/home/temp/omsresults.html'
    f = open(htmlFile, 'w+')

    message="""
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

def run_operation():
    print INSTALLER
    start_system_services()
    if operation == 'preinstall':
        install_additional_packages()
    elif operation == 'postinstall':
        detect_workspace_id()
        config_start_oms_services()
        restart_services()
    elif operation == 'status':
        result_commands()
        service_control_commands()
        write_html()

if __name__ == '__main__' :
    main()