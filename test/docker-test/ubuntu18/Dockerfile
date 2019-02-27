FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive
RUN mkdir /home/temp \
    && echo exit 0 > /usr/sbin/policy-rc.d \
    && apt-get update \
    && apt-get install -y sudo gcc curl git net-tools python-ctypes gnupg2 cron rsyslog vim dos2unix wget apache2 tzdata \
    && echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections \
    && echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections \
    && apt-get install -y mysql-server
