set -e 

restart_omsagent()
{
    if [ -x /usr/sbin/invoke-rc.d ]; then
        /usr/sbin/invoke-rc.d omsagent restart > /dev/null 2>&1 
    elif [ -x /sbin/service ]; then
        /sbin/service omsagent restart > /dev/null 2>&1 
    elif [ -x /usr/bin/systemctl ]; then
        /usr/bin/systemctl restart omsagent > /dev/null 2>&1 
    else
        echo "Unrecognized service controller to restart omsagent service" 1>&2
        exit 1
    fi
}

case "$1" in
    restart)
        restart_omsagent
        ;;
    *)
        echo "Unknown parameter : $1" 1>&2
        exit 1
        ;;
esac
