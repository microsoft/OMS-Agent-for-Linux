FROM oraclelinux:7

RUN mkdir /home/temp \
    && echo exit 0 > /usr/sbin/policy-rc.d \
    && yum update -y \
    && yum upgrade -y \
    && yum install -y gcc curl git net-tools python-ctypes gnupg2 cronie vim openssl systemd rsyslog dos2unix wget httpd \
    && wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm \
    && yum localinstall -y mysql-community-release-el7-5.noarch.rpm \
    && yum install -y mysql-community-server \
    && curl https://bootstrap.pypa.io/get-pip.py -o /home/temp/get-pip.py && python /home/temp/get-pip.py \
    && pip install pandas
