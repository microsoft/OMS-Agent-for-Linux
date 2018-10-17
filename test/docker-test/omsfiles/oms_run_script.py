import os
import os.path
import subprocess
import re
import sys
import pandas as pd
pd.set_option('display.max_colwidth', -1)


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

def linux_detect_installer_and_workspaceid():
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
        os.system('apt -y update && apt install -y git')
    elif INSTALLER == 'RPM':
        os.system('yum -y update && yum install -y git')

def disable_dsc():
    os.system('/opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py --disable')
    Pending_mof = '/etc/opt/omi/conf/omsconfig/configuration/Pending.mof'
    Current_mof = '/etc/opt/omi/conf/omsconfig/configuration/Pending.mof'
    if os.path.isfile(Pending_mof) or os.path.isfile(Current_mof):
        os.remove(Pending_mof)
        os.remove(Current_mof)

def apache_mysql_conf():
    apache_conf_dir = '/etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/apache_logs.conf'.format(workspace_id)
    mysql_conf_dir = '/etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/mysql_logs.conf'.format(workspace_id)
    os.system('chown omsagent:omiusers {0}'.format(apache_conf_dir))
    os.system('chown omsagent:omiusers {0}'.format(mysql_conf_dir))

    replace_items(mysql_conf_dir, '<mysql-general-log>', '/var/log/mysql/mysql.log')
    replace_items(mysql_conf_dir, '<mysql-error-log>', '/var/log/mysql/error.log')
    replace_items(mysql_conf_dir, '<mysql-slowquery-log>', '/var/log/mysql/slow.log')
    os.system('mkdir -p /var/log/mysql \
                && touch /var/log/mysql/mysql.log /var/log/mysql/error.log /var/log/mysql/slow.log \
                && chmod +r /var/log/mysql/* && chmod +rx /var/log/mysql')

    if INSTALLER == 'DPKG':
        replace_items(apache_conf_dir, '<apache-access-dir>', '/var/log/apache2/access.log')
        replace_items(apache_conf_dir, '<apache-error-dir>', '/var/log/apache2/error.log')
    elif INSTALLER == 'RPM':
        replace_items(apache_conf_dir, '<apache-access-dir>', '/var/log/httpd/access_log')
        replace_items(apache_conf_dir, '<apache-error-dir>', '/var/log/httpd/error_log')

def generate_data():
    os.system('rm -rf /tmp/apachefake \
            && git clone https://github.com/kiritbasu/Fake-Apache-Log-Generator /tmp/apachefake \
            && pip install -r /tmp/apachefake/requirements.txt \
            && python /tmp/apachefake/apache-fake-log-gen.py -n 100 -o LOG -p /home/temp/omsfiles/web1')
    if INSTALLER == 'APT':
        os.system('mv /home/temp/omsfiles/web1_access_log_*.log /var/log/apache2/access.log')
    elif INSTALLER == 'YUM':
        os.system('mv /home/temp/omsfiles/web1_access_log_*.log /var/log/httpd/access_log')
    elif INSTALLER == 'ZYPPER':
        os.system('mv /home/temp/omsfiles/web1_access_log_*.log /var/log/apache2/access_log')

def start_services():
    os.system('service rsyslog start')
    if INSTALLER == 'DPKG':
        os.system('service cron start \
                    && service apache2 start')
                    # && service mysql start')
    elif INSTALLER == 'RPM':
        os.system('service crond start \
                    && service httpd start')
                    # && service mysqld start')

def config_start_oms_services():
    os.system('/opt/omi/bin/omiserver -d')
    copy_config_files()
    apache_mysql_conf()
    generate_data()
    disable_dsc()

def copy_config_files():
    os.system('dos2unix /home/temp/omsfiles/perf.conf \
            && dos2unix /home/temp/omsfiles/rsyslog-oms.conf \
            && dos2unix /home/temp/omsfiles/apache_logs.conf \
            && dos2unix /home/temp/omsfiles/mysql_logs.conf \
            && cat /home/temp/omsfiles/perf.conf >> /etc/opt/microsoft/omsagent/{0}/conf/omsagent.conf \
            && cp /home/temp/omsfiles/rsyslog-oms.conf /etc/opt/omi/conf/omsconfig/rsyslog-oms.conf \
            && cp /home/temp/omsfiles/rsyslog-oms.conf /etc/rsyslog.d/95-omsagent.conf \
            && chown omsagent:omiusers /etc/rsyslog.d/95-omsagent.conf \
            && cp /home/temp/omsfiles/apache_logs.conf /etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/apache_logs.conf \
            && cp /home/temp/omsfiles/mysql_logs.conf /etc/opt/microsoft/omsagent/{0}/conf/omsagent.d/mysql_logs.conf'.format(workspace_id))

def restart_services():
    os.system('service rsyslog restart \
                &&/opt/omi/bin/service_control restart \
                && /opt/microsoft/omsagent/bin/service_control restart')

def inject_logs():
    os.system('cp /home/temp/omsfiles/mysql.log /var/log/mysql/mysql.log \
                && cp /home/temp/omsfiles/error.log /var/log/mysql/error.log \
                && cp /home/temp/omsfiles/slow.log /var/log/mysql/slow.log')

def get_status():
    os.system('/opt/microsoft/omsagent/bin/omsadmin.sh -l \
                && scxadmin -status')

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
    global onboardStatus, omiRunStatus, omiInstallOut, omsagentInstallOut, omsconfigInstallOut, scxInstallOut, omiInstallStatus, omsagentInstallStatus, omsconfigInstallStatus, scxInstallStatus, psefomsagent, omsagentRestart, omiRestart
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
        if os.system('{0} > /dev/null 2>&1'.format(cmd)) == 0:
            omiInstallStatus='Install Ok'
        else:
            omiInstallStatus='Not Installed'
        writeLogCommand(cmd)
        writeLogOutput(omiInstallOut)
        cmd='apt show omsagent'
        omsagentInstallOut=execCommand(cmd)
        if os.system('{0} > /dev/null 2>&1'.format(cmd)) == 0:
            omsagentInstallStatus='Install Ok'
        else:
            omsagentInstallStatus='Not Installed'
        writeLogCommand(cmd)
        writeLogOutput(omsagentInstallOut)
        cmd='apt show omsconfig'
        omsconfigInstallOut=execCommand(cmd)
        if os.system('{0} > /dev/null 2>&1'.format(cmd)) == 0:
            omsconfigInstallStatus='Install Ok'
        else:
            omsagentInstallStatus='Not Installed'
        writeLogCommand(cmd)
        writeLogOutput(omsconfigInstallOut)
        cmd='apt show scx'
        scxInstallOut=execCommand(cmd)
        if os.system('{0} > /dev/null 2>&1'.format(cmd)) == 0:
            scxInstallStatus='Install Ok'
        else:
            scxInstallStatus='Not Installed'
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
    install_result_variables = [[ omiInstallStatus, omiInstallOut],
                        [ omsagentInstallStatus, omsagentInstallOut],
                        [ omsconfigInstallStatus, omsconfigInstallOut],
                        [ scxInstallStatus, scxInstallOut]]
    command_result_variables = [[onboardStatus],
                            [omiRunStatus],
                            [psefomsagent],
                            [omsagentRestart],
                            [omiRestart],
                            [serviceStop],
                            [serviceDisable],
                            [serviceEnable],
                            [serviceStart]]
    install_result_columns = ['Status', 'Output']
    install_result_index = ['OMI', 'OmsAgent', 'OmsConfig', 'SCX']
    command_result_columns = ['Output']
    command_result_index = ['/opt/microsoft/omsagent/bin/omsadmin.sh -l', 'scxadmin -status', 'ps -ef | egrep "omsagent|omi"', '/opt/microsoft/omsagent/bin/service_control restart', '/opt/omi/bin/service_control restart', '/opt/microsoft/omsagent/bin/service_control stop', '/opt/microsoft/omsagent/bin/service_control disable', '/opt/microsoft/omsagent/bin/service_control enable', '/opt/microsoft/omsagent/bin/service_control stop']
    df_result = pd.DataFrame(install_result_variables, index=install_result_index, columns=install_result_columns)
    df_command = pd.DataFrame(command_result_variables, index=command_result_index, columns=command_result_columns)
    f.write("""
    <h3><caption> OMS Install Results </caption></h3>
    """)
    f.write(df_result.to_html())
    f.write("""
    <h3><caption> OMS Command Results </caption></h3>
    """)
    f.write(df_command.to_html())
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
        inject_logs()
    elif operation == 'status':
        result_commands()
        service_control_commands()
        write_html()

if __name__ == '__main__' :
    main()
