FROM debian:10

# Debian 10 Container image does not come with any python. Here we will mimic the Azure VM image and install python2 as python.
# Due to difficulty in finding the right MySQL package to trigger the mysql-cimprov package install,
# this step is skipped (though MySQL logs are still configured and collected, since they are simply custom logs).
RUN mkdir /home/temp \
    && apt-get update \
    && echo exit 0 > /usr/sbin/policy-rc.d \
    && apt-get install -y --reinstall sudo gcc curl git net-tools python2 gnupg2 cron vim procps rsyslog dos2unix systemd wget apache2 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python2 1