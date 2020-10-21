# syntax=docker/dockerfile:1.0.0-experimental

FROM registry.access.redhat.com/rhel6

RUN --mount=type=secret,id=creds,required subscription-manager register --username=$(sed -n 1p /run/secrets/creds) --password=$(sed -n 2p /run/secrets/creds)

RUN mkdir /home/temp \
    && echo exit 0 > /usr/sbin/policy-rc.d \
    && subscription-manager attach --auto \
    && yum update -y \
    && yum upgrade -y \
    && yum localinstall -y http://repo.mysql.com/mysql-community-release-el6-5.noarch.rpm \
    && yum install -y sudo gcc curl git net-tools python-ctypes gnupg2 cronie vim openssl systemd rsyslog dos2unix httpd wget mysql-community-server