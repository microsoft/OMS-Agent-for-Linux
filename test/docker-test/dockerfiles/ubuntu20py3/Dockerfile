FROM ubuntu:20.04

# Due to difficulty in finding the right MySQL package to trigger the mysql-cimprov package install,
# this step is skipped (though MySQL logs are still configured and collected, since they are simply custom logs).
ARG DEBIAN_FRONTEND=noninteractive
RUN mkdir /home/temp \
    && echo exit 0 > /usr/sbin/policy-rc.d \
    && apt-get update \
    && apt-get install -y sudo gcc curl git net-tools python3 gnupg2 cron rsyslog vim dos2unix wget apache2 systemd tzdata iproute2
