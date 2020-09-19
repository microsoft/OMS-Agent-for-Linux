FROM centos:8

# Due to difficulty in finding the right MySQL package to trigger the mysql-cimprov package install,
# this step is skipped (though MySQL logs are still configured and collected, since they are simply custom logs).
RUN mkdir /home/temp \
    && yum update -y \
    && yum upgrade -y \
    && yum install -y sudo gcc git net-tools cronie openssl dos2unix wget httpd rsyslog python3 initscripts hostname systemd vim gnupg2 curl

ENTRYPOINT ["/usr/sbin/init"]
