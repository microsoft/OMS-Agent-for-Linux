FROM oraclelinux:6

RUN mkdir /home/temp \
    && echo exit 0 > /usr/sbin/policy-rc.d \
    && yum update -y \
    && yum upgrade -y \
    && yum install -y gcc net-tools python-ctypes gnupg2 cronie vim openssl systemd rsyslog dos2unix httpd wget \
    && wget http://repo.mysql.com/mysql-community-release-el6-5.noarch.rpm \
    && yum localinstall -y mysql-community-release-el6-5.noarch.rpm \
    && yum install -y mysql-community-server \
    && wget -O /etc/yum.repos.d/public-yum-ol6.repo http://yum.oracle.com/public-yum-ol6.repo \
    && yum-config-manager --enable ol6_latest ol6_software_collections \
    && yum install -y python27-python-pip \
    && scl enable python27 -- pip install -U requests adal \
    && echo 'source scl_source enable python27' >> /root/.bashrc
