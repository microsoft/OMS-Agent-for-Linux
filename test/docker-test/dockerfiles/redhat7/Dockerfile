# syntax=docker/dockerfile:1.0.0-experimental

FROM registry.access.redhat.com/rhel7

RUN --mount=type=secret,id=creds,required subscription-manager register --username=$(sed -n 1p /run/secrets/creds) --password=$(sed -n 2p /run/secrets/creds)

RUN mkdir /home/temp \
    && subscription-manager attach --auto \
    && yum update -y \
    && yum upgrade -y \
    && yum localinstall -y http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm \
    && yum install -y sudo gcc curl git net-tools gnupg2 cronie vim openssl systemd dos2unix wget httpd rsyslog python-ctypes hostname initscripts mysql-community-server

ENTRYPOINT ["/usr/sbin/init"]