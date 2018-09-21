FROM centos/systemd

RUN mkdir /home/temp && echo exit 0 > /usr/sbin/policy-rc.d && yum update -y && yum upgrade -y && yum -y install python-ctypes gnupg2 rsyslog cron vim openssl

# EXPOSE 80

# CMD ["/usr/sbin/init"]

