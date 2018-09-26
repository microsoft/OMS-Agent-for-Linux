FROM oraclelinux:7

RUN mkdir /home/temp && echo exit 0 > /usr/sbin/policy-rc.d && yum update -y && yum upgrade -y && \
    yum -y install python-ctypes gnupg2 cronie vim openssl systemd rsyslog dos2unix
