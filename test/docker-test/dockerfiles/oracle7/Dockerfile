FROM oraclelinux:7

RUN mkdir /home/temp \
    && echo exit 0 > /usr/sbin/policy-rc.d \
    && yum update -y \
    && yum upgrade -y \
    && yum install -y sudo gcc curl git net-tools python-ctypes gnupg2 cronie vim openssl systemd rsyslog dos2unix wget httpd \
    && wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm \
    && yum localinstall -y mysql-community-release-el7-5.noarch.rpm \
    && yum install -y mysql-community-server

ENTRYPOINT ["/usr/sbin/init"]
