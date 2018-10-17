FROM ubuntu:18.04

RUN mkdir /home/temp \
    && echo exit 0 > /usr/sbin/policy-rc.d \
    && apt-get update \
    && apt-get install -y gcc curl git net-tools python-ctypes gnupg2 cron rsyslog vim dos2unix wget apache2 \
    && echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections \
    && echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections \
    && apt-get install -y mysql-server \
    && curl https://bootstrap.pypa.io/get-pip.py -o /home/temp/get-pip.py && python /home/temp/get-pip.py \
    && pip install pandas
