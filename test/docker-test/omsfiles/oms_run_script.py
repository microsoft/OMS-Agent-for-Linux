import os
import os.path
import re
import sys
import shutil

operation = None

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
    except:
        if operation is None:
            print "No operation specified. run with 'preinstall' or 'postinstall'"

    run_operation()

def replace_items(infile, old_word, new_word):
    if not os.path.isfile(infile):
        print("Error on replace_word, not a regular file: " + infile)
        sys.exit(1)

    f1 = open(infile, 'r').read()
    f2 = open(infile, 'w')
    m = f1.replace(old_word,new_word)
    f2.write(m)

def install_additional_packages():
    #Add additional packages command here
    if INSTALLER == 'DPKG':
        os.system('apt update')
    elif INSTALLER == 'RPM':
        os.system('yum update')

def disable_dsc():
    os.system('/opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py --disable')
    Pending_mof = '/etc/opt/omi/conf/omsconfig/configuration/Pending.mof'
    Current_mof = '/etc/opt/omi/conf/omsconfig/configuration/Pending.mof'
    if os.path.isfile(Pending_mof) or os.path.isfile(Current_mof):
        os.remove(Pending_mof)
        os.remove(Current_mof)

def apache_mysql_conf():
    apache_conf_dir = '/etc/opt/microsoft/omsagent/conf/omsagent.d/apache_logs.conf'
    mysql_conf_dir = '/etc/opt/microsoft/omsagent/conf/omsagent.d/mysql_logs.conf'
    #shutil.copy('/home/temp/omsfiles/mysql_logs.conf', mysql_conf_dir)
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

def start_services():
    os.system('service rsyslog start')
    os.system('chown -R mysql:mysql /var/lib/mysql')
    if INSTALLER == 'DPKG':
        os.system('service cron start \
                    && service apache2 start \
                    && service mysql start')
    elif INSTALLER == 'RPM':
        os.system('service crond start \
                    && service httpd start \
                    && service mysqld start')

def config_start_oms_services():
    os.system('/opt/omi/bin/omiserver -d')
    copy_config_files()
    apache_mysql_conf()
    disable_dsc()

def copy_config_files():
    os.system('dos2unix /home/temp/omsfiles/perf.conf \
            && dos2unix /home/temp/omsfiles/rsyslog-oms.conf \
            && dos2unix /home/temp/omsfiles/apache_logs.conf \
            && dos2unix /home/temp/omsfiles/mysql_logs.conf \
            && cat /home/temp/omsfiles/perf.conf >> /etc/opt/microsoft/omsagent/conf/omsagent.conf \
            && cp /home/temp/omsfiles/rsyslog-oms.conf /etc/opt/omi/conf/omsconfig/rsyslog-oms.conf \
            && cp /home/temp/omsfiles/apache_logs.conf /etc/opt/microsoft/omsagent/conf/omsagent.d/apache_logs.conf \
            && cp /home/temp/omsfiles/mysql_logs.conf /etc/opt/microsoft/omsagent/conf/omsagent.d/mysql_logs.conf')

def restart_services():
    os.system('/opt/omi/bin/service_control restart \
                && /opt/microsoft/omsagent/bin/service_control restart')

def inject_logs():
    os.system('cp /home/temp/omsfiles/mysql.log /var/log/mysql/mysql.log \
                && cp /home/temp/omsfiles/error.log /var/log/mysql/error.log \
                && cp /home/temp/omsfiles/slow.log /var/log/mysql/slow.log')

def get_status():
    os.system('/opt/microsoft/omsagent/bin/omsadmin.sh -l \
                && scxadmin -status')

def run_operation():
    if operation == 'preinstall':
        install_additional_packages()
    elif operation == 'postinstall':
        start_services()
        config_start_oms_services()
        restart_services()
        inject_logs()

if __name__ == '__main__' :
    main()
