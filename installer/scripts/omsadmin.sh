#!/bin/sh

set -e

TMP_DIR=/var/opt/microsoft/omsagent/tmp
CERT_DIR=/etc/opt/microsoft/omsagent/certs
CONF_DIR=/etc/opt/microsoft/omsagent/conf
SYSCONF_DIR=/etc/opt/microsoft/omsagent/sysconf
COLLECTD_DIR=/etc/collectd/collectd.conf.d

# Optional file with initial onboarding credentials
FILE_ONBOARD=/etc/omsagent-onboard.conf

# Generated conf file containing information for this script
CONF_OMSADMIN=$CONF_DIR/omsadmin.conf

# Omsagent daemon configuration
CONF_OMSAGENT=$CONF_DIR/omsagent.conf

# Omsagent proxy configuration
CONF_PROXY=$CONF_DIR/proxy.conf

# File with OS information for telemetry
OS_INFO=/etc/opt/microsoft/scx/conf/scx-release

# File with information about the agent installed
INSTALL_INFO=/etc/opt/microsoft/omsagent/sysconf/installinfo.txt

# Ruby helpers
RUBY=/opt/microsoft/omsagent/ruby/bin/ruby
AUTH_KEY_SCRIPT=/opt/microsoft/omsagent/bin/auth_key.rb
TOPOLOGY_REQ_SCRIPT=/opt/microsoft/omsagent/plugin/agent_topology_request_script.rb

METACONFIG_PY=/opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py

# Certs
FILE_KEY=$CERT_DIR/oms.key
FILE_CRT=$CERT_DIR/oms.crt

# Temporary files
SHARED_KEY_FILE=$TMP_DIR/shared_key
BODY_ONBOARD=$TMP_DIR/body_onboard.xml
RESP_ONBOARD=$TMP_DIR/resp_onboard.xml

BODY_HEARTBEAT=$TMP_DIR/body_heartbeat.xml
RESP_HEARTBEAT=$TMP_DIR/resp_heartbeat.xml

BODY_RENEW_CERT=$TMP_DIR/body_renew_cert.xml
RESP_RENEW_CERT=$TMP_DIR/resp_renew_cert.xml

AGENT_USER=omsagent
AGENT_GROUP=omsagent

# Default settings
URL_TLD=opinsights.azure.com
WORKSPACE_ID=""
AGENT_GUID=""
LOG_FACILITY=local0
CERTIFICATE_UPDATE_ENDPOINT=""
VERBOSE=0
AZURE_RESOURCE_ID=""
OMSCLOUD_ID=""
UUID=""
USER_ID=`id -u`

usage()
{
    local basename=`basename $0`
    echo
    echo "Maintenance tool for OMS:"
    echo "Onboarding:"
    echo "$basename -w <workspace id> -s <shared key> [-d <top level domain>]"
    echo
    echo "Heartbeat:"
    echo "$basename -b"
    echo
    echo "Renew certificates:"
    echo "$basename -r"
    echo
    echo "Define proxy settings ('-u' will prompt for password):"
    echo "$basename [-u user] -p host[:port]"
    echo
    echo "Enable collectd:"
    echo "$basename -c"
    echo
    echo "Azure resource ID:"
    echo "$basename -a <Azure resource ID>"
    clean_exit 1
}

set_user_agent()
{
    USER_AGENT=LinuxMonitoringAgent/`head -1 $INSTALL_INFO | awk '{print $1}'`
}

check_user()
{
    if [ "$USER_ID" -ne "0" -a `id -un` != "$AGENT_USER" ]; then
        log_error "This script must be run as root or as the $AGENT_USER user."
        exit 1
    fi
}

chown_omsagent()
{
    # When this script is run as root, we still have to make sure the generated
    # files are owned by omsagent for everything to work properly
    [ "$USER_ID" -eq "0" ] && chown $AGENT_USER:$AGENT_GROUP $@ > /dev/null 2>&1
    return 0
}

save_config()
{
    #Save configuration
    echo WORKSPACE_ID=$WORKSPACE_ID > $CONF_OMSADMIN
    echo AGENT_GUID=$AGENT_GUID >> $CONF_OMSADMIN
    echo LOG_FACILITY=$LOG_FACILITY >> $CONF_OMSADMIN
    echo CERTIFICATE_UPDATE_ENDPOINT=$CERTIFICATE_UPDATE_ENDPOINT >> $CONF_OMSADMIN
    echo URL_TLD=$URL_TLD >> $CONF_OMSADMIN
    echo DSC_ENDPOINT=$DSC_ENDPOINT >> $CONF_OMSADMIN
    echo OMS_ENDPOINT=https://$WORKSPACE_ID.ods.$URL_TLD/OperationalData.svc/PostJsonDataItems >> $CONF_OMSADMIN
    echo AZURE_RESOURCE_ID=$AZURE_RESOURCE_ID >> $CONF_OMSADMIN
    echo OMSCLOUD_ID=$OMSCLOUD_ID | tr -d ' ' >> $CONF_OMSADMIN
    echo UUID=$UUID | tr -d ' ' >> $CONF_OMSADMIN
    chown_omsagent "$CONF_OMSADMIN"
}

load_config()
{
    if [ ! -e "$CONF_OMSADMIN" ]; then
        log_error "Missing configuration file : $CONF_OMSADMIN"
        clean_exit 1
    fi

    . "$CONF_OMSADMIN"

    if [ -z "$WORKSPACE_ID" -o -z "$AGENT_GUID" ]; then
        log_error "Missing required field from configuration file: $CONF_OMSADMIN"
        clean_exit 1
    fi

    # In the upgrade scenario, the URL_TLD doesn't have the .com part
    # Append it to make it backward-compatible
    if [ "$URL_TLD" = "opinsights.azure" -o "$URL_TLD" = "int2.microsoftatlanta-int" ]; then
        URL_TLD="${URL_TLD}.com"
    fi
}

cleanup()
{
    rm "$BODY_ONBOARD" "$RESP_ONBOARD" > /dev/null 2>&1 || true
    rm "$BODY_HEARTBEAT" "$RESP_HEARTBEAT" > /dev/null 2>&1 || true
    rm "$BODY_RENEW_CERT" "$RESP_RENEW_CERT" > /dev/null 2>&1 || true
}

clean_exit()
{
    cleanup
    exit $1
}

log_info()
{
    echo -e "info\t$1"
    logger -i -p "$LOG_FACILITY".info -t omsagent "$1"
}

log_warning()
{
    echo -e "warning\t$1"
    logger -i -p "$LOG_FACILITY".warning -t omsagent "$1"
}

log_error()
{
    echo -e "error\t$1"
    logger -i -p "$LOG_FACILITY".err -t omsagent "$1"
}

parse_args()
{
    local OPTIND opt

    while getopts "h?s:w:d:brvp:u:a:c" opt; do
        case "$opt" in
        h|\?)
            usage
            ;;
        s)
            ONBOARDING=1
            SHARED_KEY=$OPTARG
            ;;
        w)
            ONBOARDING=1
            WORKSPACE_ID=$OPTARG
            ;;
        d)
            ONBOARDING=1
            URL_TLD=$OPTARG
            ;;
        b)
            HEARTBEAT=1
            ;;
        r)
            RENEW_CERT=1
            ;;
        v)
            VERBOSE=1
            CURL_VERBOSE=-v
            ;;
        p)
            PROXY_HOST=$OPTARG
            ;;
        u)
            PROXY_USER=$OPTARG
            ;;
        a)
            AZURE_RESOURCE_ID=$OPTARG
            ;;
        c) 
            COLLECTD=1
            echo "Setting up collectd for OMS..."
            ;;
        esac
    done
    shift $((OPTIND-1))

    if [ "$@ " != " " ]; then
        log_error "Parsing error: '$@' is unparsed"
        usage
    fi

    if [ -n "$PROXY_USER" -a -z "$PROXY_HOST" ]; then
        log_error "Cannot specify the proxy user without specifying the proxy host"
        usage
    fi

    if [ -n "$PROXY_HOST" ]; then
        if [ -n "$PROXY_USER" ]; then
            read -s -p "Proxy password for $PROXY_USER: " PROXY_PASS
            echo
            create_proxy_conf "$PROXY_USER:$PROXY_PASS@$PROXY_HOST"
        else
            create_proxy_conf "$PROXY_HOST"
        fi
    fi

    if [ $VERBOSE -eq 0 ]; then
        # Suppress curl output
        CURL_VERBOSE=-s
    fi
}

generate_certs()
{
    log_info "Generating certificate ..."
    local tmp_key="$FILE_KEY.tmp"
    local error=0

    # Set safe certificate permissions before to prevent timing attacks
    touch "$tmp_key" "$FILE_KEY" "$FILE_CRT"
    chown_omsagent "$tmp_key" "$FILE_KEY" "$FILE_CRT"
    chmod 600 "$tmp_key" "$FILE_KEY" "$FILE_CRT"

    openssl req -subj "/CN=$WORKSPACE_ID/CN=$AGENT_GUID/OU=Linux Monitoring Agent/O=Microsoft" -new -newkey \
        rsa:2048 -days 365 -nodes -x509 -sha256 -keyout "$tmp_key" -out "$FILE_CRT" > /dev/null 2>&1 || error=$?

    if [ $error -ne 0 -o ! -e "$tmp_key" -o ! -e "$FILE_CRT" ]; then
        log_error "Error generating certs"
        clean_exit 1
    fi

    # Convert key to rsa format for older systems
    openssl rsa -in "$tmp_key" -out "$FILE_KEY" > /dev/null 2>&1
    rm "$tmp_key"
}

set_FQDN()
{
    local hostname=`hostname`
    local domainname=`hostname -d 2> /dev/null`

    if [ -n "$domainname" ]; then
        FQDN="$hostname.$domainname"
    else
        FQDN="$hostname"
    fi
}

create_proxy_conf()
{
    local conf_proxy_content=$1
    touch $CONF_PROXY
    chown_omsagent $CONF_PROXY
    chmod 600 $CONF_PROXY
    echo -n $conf_proxy_content > $CONF_PROXY
    log_info "Created proxy configuration: $CONF_PROXY"
}

set_proxy_setting()
{
    if [ -n "$PROXY" ]; then
        PROXY_SETTING="--proxy $PROXY"
        create_proxy_conf "$PROXY"
        return
    fi
    local conf_proxy_content=""
    [ -r "$CONF_PROXY" ] && conf_proxy_content=`cat $CONF_PROXY`
    if [ -n "$conf_proxy_content" ]; then
        PROXY_SETTING="--proxy $conf_proxy_content"
        log_info "Using proxy settings from '$CONF_PROXY'"
    fi
}

onboard()
{
    if [ $VERBOSE -eq 1 ]; then
        echo "Workspace ID:      $WORKSPACE_ID"
        echo "Shared key:        $SHARED_KEY"
        echo "Top Level Domain:  $URL_TLD"
    fi

    local error=0
    if [ -z "$WORKSPACE_ID" -o -z "$SHARED_KEY" ]; then
        log_error "Missing Wokspace ID or Shared Key information for onboarding"
        clean_exit 1
    fi

    if echo "$WORKSPACE_ID" | grep -Eqv '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'; then
        log_error "The Workspace ID is not valid"
        clean_exit 1
    fi

    PREV_WID=`grep WORKSPACE_ID $CONF_OMSADMIN 2> /dev/null | cut -d= -f2`
    if [ -f $FILE_KEY -a -f $FILE_CRT -a -f $CONF_OMSADMIN -a "$PREV_WID" = $WORKSPACE_ID ]; then
        # Keep the same agent GUID by loading it from the previous conf
        AGENT_GUID=`grep AGENT_GUID $CONF_OMSADMIN | cut -d= -f2`
        log_info "Reusing previous agent GUID"
    else
        AGENT_GUID=`$RUBY -e "require 'securerandom'; print SecureRandom.uuid"`
        generate_certs
    fi

    if [ -z "$AGENT_GUID" ]; then
        log_error "AGENT_GUID should not be empty"
        return 1
    fi

    if [ "$VERBOSE" = "1" ]; then
        log_info "Private Key stored in:   $FILE_KEY"
        log_info "Public Key stored in:    $FILE_CRT"
        # Public key can be verified with a command like:  openssl x509 -text -in oms.crt
    fi

    # Generate the body first so we can compute a SHA256 on the body

    REQ_DATE=`date +%Y-%m-%dT%T.%N%:z`
    CERT_SERVER=`cat $FILE_CRT | awk 'NR>2 { print line } { line = $0 }'`
    set_FQDN
 
    # append telemetry to $BODY_ONBOARD
    `$RUBY $TOPOLOGY_REQ_SCRIPT -t "$BODY_ONBOARD" "$OS_INFO" "$CONF_OMSADMIN" "$FQDN" "$AGENT_GUID" "$CERT_SERVER"` 
    [ $? -ne 0 ] && log_error "Error appending Telemetry during Onboarding. "

    cat /dev/null > "$SHARED_KEY_FILE"
    chmod 600 "$SHARED_KEY_FILE"
    echo -n "$SHARED_KEY" >> "$SHARED_KEY_FILE"
    AUTHS=`$RUBY $AUTH_KEY_SCRIPT $REQ_DATE $BODY_ONBOARD $SHARED_KEY_FILE`
    rm "$SHARED_KEY_FILE"

    CONTENT_HASH=`echo $AUTHS | cut -d" " -f1`
    AUTHORIZATION_KEY=`echo $AUTHS | cut -d" " -f2`

    if [ $VERBOSE -ne 0 ]; then
        echo
        echo "Generated request:"
        cat $BODY_ONBOARD
    fi

    set_proxy_setting

    if [ "`which dmidecode > /dev/null 2>&1; echo $?`" = 0 ]; then
        UUID=`dmidecode | grep UUID | sed -e 's/UUID: //'`
        OMSCLOUD_ID=`dmidecode | grep "Tag: 77" | sed -e 's/Asset Tag: //'`
    elif [ -f /sys/devices/virtual/dmi/id/chassis_asset_tag ]; then
        ASSET_TAG=$(cat /sys/devices/virtual/dmi/id/chassis_asset_tag)
        case "$ASSET_TAG" in
            77*) OMSCLOUD_ID=$ASSET_TAG ;;       # If the asset tag begins with a 77 this is the azure guid
        esac
    fi     
 
    RET_CODE=`curl --header "x-ms-Date: $REQ_DATE" \
        --header "x-ms-version: August, 2014" \
        --header "x-ms-SHA256_Content: $CONTENT_HASH" \
        --header "Authorization: $WORKSPACE_ID; $AUTHORIZATION_KEY" \
        --header "User-Agent: $USER_AGENT" \
        --header "Accept-Language: en-US" \
        --insecure \
        --data-binary @$BODY_ONBOARD \
        --cert "$FILE_CRT" --key "$FILE_KEY" \
        --output "$RESP_ONBOARD" $CURL_VERBOSE \
        --write-out "%{http_code}\n" $PROXY_SETTING \
        https://${WORKSPACE_ID}.oms.${URL_TLD}/AgentService.svc/LinuxAgentTopologyRequest` || error=$?
                 
    if [ $error -ne 0 ]; then
        log_error "Error during the onboarding request. Check the correctness of the workspace ID and shared key or run omsadmin.sh with '-v'"
        rm "$FILE_CRT" "$FILE_KEY" > /dev/null 2>&1 || true
        return 1
    fi

    if [ "$RET_CODE" = "200" ]; then
        apply_dsc_endpoint $RESP_ONBOARD
        log_info "Onboarding success"
    elif [ "$RET_CODE" = "403" ]; then
        REASON=`cat $RESP_ONBOARD | sed -n 's:.*<Reason>\(.*\)</Reason>.*:\1:p'`
        log_error "Error onboarding. HTTP code 403, Reason: $REASON. Check the Workspace ID, Workspace Key and that the time of the system is correct."
        rm "$FILE_CRT" "$FILE_KEY" > /dev/null 2>&1 || true
        return 1
    else
        log_error "Error onboarding. HTTP code $RET_CODE"
        rm "$FILE_CRT" "$FILE_KEY" > /dev/null 2>&1 || true
        return 1
    fi

    save_config

    # If a test is not in progress then register omsagent as a service and start the agent 
    if [ -z "$TEST_WORKSPACE_ID" -a -z "$TEST_SHARED_KEY" ]; then
        /opt/microsoft/omsagent/bin/service_control start 
    fi

    if [ -e $METACONFIG_PY ]; then
        if [ "$USER_ID" -eq "0" ]; then
            su - omsagent -c $METACONFIG_PY > /dev/null
        else
            $METACONFIG_PY > /dev/null || error=$?
        fi

        if [ $error -eq 0 ]; then
            log_info "Configured omsconfig"
        else
            log_error "Error configuring omsconfig"
            return 1
        fi
    fi

    # Set up a cron job to run the OMSConsistencyInvoker every 5 minutes
    if [ ! -f /etc/cron.d/OMSConsistencyInvoker ]; then
        echo "*/5 * * * * $AGENT_USER /opt/omi/bin/OMSConsistencyInvoker >/dev/null 2>&1" > /etc/cron.d/OMSConsistencyInvoker
    fi
    return 0
}

apply_certificate_update_endpoint()
{
    # Update the CERTIFICATE_UPDATE_ENDPOINT variable and call renew_cert if the server asks
    local xml_file=$1
    # Extract the certificate update endpoint from the server response
    ENDPOINT_TAG=`grep -o "<CertificateUpdateEndpoint.*CertificateUpdateEndpoint>" $xml_file`
    CERTIFICATE_UPDATE_ENDPOINT=`echo $ENDPOINT_TAG | grep -o https.*RenewCertificate`

    if [ -z "$CERTIFICATE_UPDATE_ENDPOINT" ]; then
        log_error "Could not extract the update certificate endpoint."
        return 1
    fi

    # Check in the response if the certs should be renewed
    UPDATE_ATTR=`echo "$ENDPOINT_TAG" | grep -oP "updateCertificate=\"((true|false))\""`
    if [ -z "UPDATE_ATTR" ]; then
        log_error "Could not find the updateCertificate tag in the heartbeat response"
        return 1
    fi

    if echo "$UPDATE_ATTR" | grep "true"; then
        renew_cert
    fi
}

apply_dsc_endpoint()
{
    # Updates the DSC_ENDPOINT variable
    local xml_file=$1
    # Extract the DSC endpoint from the server response
    DSC_CONF=`grep -o "<DscConfiguration.*DscConfiguration>" $xml_file`
    DSC_ENDPOINT=`echo $DSC_CONF | grep -o "<Endpoint>.*</Endpoint>" | sed -e "s/<.\?Endpoint>//g" -e "s/(/\\\\\(/g" -e "s/)/\\\\\)/g"`

    if [ -z "$DSC_ENDPOINT" ]; then
        log_error "Could not extract the DSC endpoint."
        return 1
    fi
}

heartbeat()
{
    load_config

    # Generate the request body
    CERT_SERVER=`cat "$FILE_CRT" | awk 'NR>2 { print line } { line = $0 }'`
    set_FQDN

    `$RUBY $TOPOLOGY_REQ_SCRIPT -t "$BODY_HEARTBEAT" "$OS_INFO" "$CONF_OMSADMIN" "$FQDN" "$AGENT_GUID" "$CERT_SERVER"`
    [ $? -ne 0 ] && log_error "Error when appending Telemetry to Heartbeat" 

    set_proxy_setting

    REQ_DATE=`date +%Y-%m-%dT%T.%N%:z`
    RET_CODE=`curl --header "x-ms-Date: $REQ_DATE" \
        --header "User-Agent: $USER_AGENT" \
        --header "Accept-Language: en-US" \
        --insecure \
        --data-binary @$BODY_HEARTBEAT \
        --cert "$FILE_CRT" --key "$FILE_KEY" \
        --output "$RESP_HEARTBEAT" $CURL_VERBOSE \
        --write-out "%{http_code}\n" $PROXY_SETTING \
        https://${WORKSPACE_ID}.oms.${URL_TLD}/AgentService.svc/LinuxAgentTopologyRequest`

    if [ "$RET_CODE" = "200" ]; then
        apply_certificate_update_endpoint $RESP_HEARTBEAT
        apply_dsc_endpoint $RESP_HEARTBEAT
        log_info "Heartbeat success"

        # Save the current certificate endpoint url
        save_config
    else
        log_error "Error sending the heartbeat. HTTP code $RET_CODE"
        return 1
    fi
}

renew_cert()
{
    local error=0
    load_config

    if [ -z "$CERTIFICATE_UPDATE_ENDPOINT" ]; then
        log_error "Missing CERTIFICATE_UPDATE_ENDPOINT from configuration"
        return 1
    fi

    log_info "Renewing the certificates"

    # Save old certs
    mv "$FILE_CRT" "$FILE_CRT".old
    mv "$FILE_KEY" "$FILE_KEY".old

    generate_certs

    CERT_SERVER=`cat "$FILE_CRT" | awk 'NR>2 { print line } { line = $0 }'`
    echo '<?xml version="1.0"?>' > $BODY_RENEW_CERT
    echo '<CertificateUpdateRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://schemas.microsoft.com/WorkloadMonitoring/HealthServiceProtocol/2014/09/">' >> $BODY_RENEW_CERT
    echo "   <NewCertificate>${CERT_SERVER}</NewCertificate>" >> $BODY_RENEW_CERT
    echo "</CertificateUpdateRequest>" >> $BODY_RENEW_CERT

    set_proxy_setting

    RET_CODE=`curl --insecure \
    --data-binary @$BODY_RENEW_CERT \
    --cert "$FILE_CRT".old --key "$FILE_KEY".old \
    --output "$RESP_RENEW_CERT" $CURL_VERBOSE \
    --write-out "%{http_code}\n" $PROXY_SETTING \
    "$CERTIFICATE_UPDATE_ENDPOINT"`

    if [ "$RET_CODE" = "200" ]; then
        # Do one heartbeat for the server to acknowledge the change
        heartbeat || error=$?

        if [ $error -eq 0 ]; then
            log_info "Certificates successfully renewed"
            rm "$FILE_CRT".old "$FILE_KEY".old
        else
            log_error "Error renewing certificate. Restoring old certs."
            # Restore old certs
            mv "$FILE_CRT".old "$FILE_CRT"
            mv "$FILE_KEY".old "$FILE_KEY"
            return 1
        fi
    else
        log_error "Error renewing certificate. HTTP code $RET_CODE"

        # Restore old certs
        mv "$FILE_CRT".old "$FILE_CRT"
        mv "$FILE_KEY".old "$FILE_KEY"
        return 1
    fi
}

collectd()
{
    if [ -d "$COLLECTD_DIR" ]; then
        cp $SYSCONF_DIR/omsagent.d/oms.conf $COLLECTD_DIR/oms.conf
        cp $SYSCONF_DIR/omsagent.d/collectd.conf $CONF_DIR/omsagent.d/collectd.conf
        chown omsagent:omsagent $CONF_DIR/omsagent.d/collectd.conf
        /opt/microsoft/omsagent/bin/service_control restart 
    else
        echo "$COLLECTD_DIR - directory does not exist. Please make sure collectd is installed properly"
        return 1
    fi
    echo "...Done"
}
main()
{
    check_user
    set_user_agent
    parse_args $@

    if [ $# -eq 0 ] || [ $# -eq 1 -a "$VERBOSE" = "1" ]; then

        # Allow onboarding params to be loaded from a file
        # The file contains at least these two lines :
        # WORKSPACE_ID="[...]"
        # SHARED_KEY="[...]"

        if [ -r "$FILE_ONBOARD" ]; then
            log_info "Reading onboarding params from: $FILE_ONBOARD"
            . "$FILE_ONBOARD"
            ONBOARDING=1
            ONBOARD_FROM_FILE=1
        else
            usage
        fi
    fi

    if [ "$ONBOARDING" = "1" ]; then
        onboard || clean_exit 1
    fi

    if [ "$HEARTBEAT"  = "1" ]; then
        heartbeat || clean_exit 1
    fi

    if [ "$RENEW_CERT" = "1" ]; then
        renew_cert || clean_exit 1
    fi

    if [ "$COLLECTD" = "1" ]; then
        collectd || clean_exit 1
    fi
	
    # If we reach this point, onboarding was successful, we can remove the
    # onboard conf to prevent accidentally re-onboarding 
    [ "$ONBOARD_FROM_FILE" = "1" ] && rm "$FILE_ONBOARD" > /dev/null 2>&1 || true
  
    clean_exit 0
}

main $@
