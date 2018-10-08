FROM jvssvarma/centos7-baseimage:7

RUN yum install -y yum-plugin-ovl
RUN mkdir /home/temp \
    && echo exit 0 > /usr/sbin/policy-rc.d \
    && yum update -y \
    && yum install -y gcc net-tools python-ctypes gnupg2 systemd rsyslog cronie vim openssl dos2unix httpd wget \
    && wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm \
    && yum localinstall -y mysql-community-release-el7-5.noarch.rpm \
    && yum install -y mysql-community-server centos-release-scl epel-release \
    && yum install -y python-devel python-pip \
    && pip install -U requests adal

ENTRYPOINT ["/usr/sbin/init"]
