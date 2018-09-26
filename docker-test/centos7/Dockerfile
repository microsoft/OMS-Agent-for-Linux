FROM centos7-custom:7
RUN yum -y install yum-plugin-ovl 
RUN mkdir /home/temp && echo exit 0 > /usr/sbin/policy-rc.d && yum update -y && yum -y install python-ctypes gnupg2 systemd rsyslog cronie vim openssl dos2unix

ENTRYPOINT ["/usr/sbin/init"]

