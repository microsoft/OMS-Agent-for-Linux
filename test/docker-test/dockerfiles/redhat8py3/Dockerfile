# syntax=docker/dockerfile:1.0.0-experimental

FROM registry.access.redhat.com/ubi8

RUN --mount=type=secret,id=creds,required subscription-manager register --username=$(sed -n 1p /run/secrets/creds) --password=$(sed -n 2p /run/secrets/creds)

# Due to difficulty in finding the right MySQL package to trigger the mysql-cimprov package install,
# this step is skipped (though MySQL logs are still configured and collected, since they are simply custom logs).
# TODO when python2/3 coexistence is complete, remove alternatives command
RUN mkdir /home/temp \
    && subscription-manager attach --auto \
    && yum update -y \
    && yum upgrade -y \
    && yum install -y sudo gcc git net-tools cronie openssl dos2unix wget httpd rsyslog python3 initscripts hostname iproute

ENTRYPOINT ["/usr/sbin/init"]
