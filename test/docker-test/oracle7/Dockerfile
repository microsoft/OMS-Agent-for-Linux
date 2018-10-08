FROM oraclelinux:7

RUN mkdir /home/temp \
    && echo exit 0 > /usr/sbin/policy-rc.d \
    && yum update -y \
    && yum upgrade -y \
    && yum install -y gcc net-tools python-ctypes gnupg2 cronie vim openssl systemd rsyslog dos2unix wget httpd \
    && wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm \
    && yum localinstall -y mysql-community-release-el7-5.noarch.rpm \
    && yum install -y mysql-community-server \
    && wget -O /etc/yum.repos.d/public-yum-ol7.repo http://yum.oracle.com/public-yum-ol7.repo \
    && yum-config-manager --enable ol7_latest ol7_optional_latest ol7_software_collections \
    && yum install -y python27-python-pip \
    && scl enable python27 -- pip install -U requests adal \
    && echo 'source scl_source enable python27' >> /root/.bashrc

