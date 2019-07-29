FROM debian:9

RUN mkdir /home/temp \
    && apt-get update \
    && echo exit 0 > /usr/sbin/policy-rc.d \
    && apt-get install -y --reinstall sudo gcc curl git net-tools python-ctypes gnupg2 cron vim procps rsyslog dos2unix wget apache2 \
    && echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections \
    && echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections \
    && apt-get install -y mysql-server
