set -e

case "$1" in
    tcp)
        sed -i "s/protocol_type udp/protocol_type tcp/" /etc/opt/microsoft/omsagent/conf/omsagent.conf
        sed -i "s/ @1/ @@1/" /etc/rsyslog.d/95-omsagent.conf
        service rsyslog restart
        service omsagent restart
        ;;

    udp)
        sed -i "s/protocol_type tcp/protocol_type udp/" /etc/opt/microsoft/omsagent/conf/omsagent.conf
        sed -i "s/ @@1/ @1/" /etc/rsyslog.d/95-omsagent.conf
        service rsyslog restart
        service omsagent restart
        ;;
    get)
        grep protocol_type /etc/opt/microsoft/omsagent/conf/omsagent.conf
        ;;
    *)
        echo "Unknown argument: '$1'" >&2
        echo "Use tcp, udp or get" >&2
        ;;
esac
