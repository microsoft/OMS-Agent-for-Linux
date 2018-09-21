FROM debian:8

RUN mkdir /home/temp && echo exit 0 > /usr/sbin/policy-rc.d && \
apt-get update && apt-get -y install python-ctypes gnupg2 cron vim systemd rsyslog
