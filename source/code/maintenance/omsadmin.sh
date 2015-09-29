#!/usr/bin/env bash

set -e

# Folder for temporary generated files
TMP_DIR=/var/opt/microsoft/omsagent/tmp
# File with initial onboarding credentials
FILE_ONBOARD=/etc/omsagent-onboard.conf
# Generated conf file containing information for this script
CONF_FILENAME=/etc/opt/microsoft/omsagent/conf/omsadmin.conf
# Certs
FILE_KEY=/etc/opt/microsoft/omsagent/certs/oms.key
FILE_CRT=/etc/opt/microsoft/omsagent/certs/oms.crt
URL_TLD=opinsights.azure

HEADER_ONBOARD="$TMP_DIR"/header_onboard.out
BODY_ONBOARD="$TMP_DIR"/body_onboard.xml
RESP_ONBOARD="$TMP_DIR"/resp_onboard.xml

BODY_HEARTBEAT="$TMP_DIR"/body_heartbeat.xml
RESP_HEARTBEAT="$TMP_DIR"/resp_heartbeat.xml

BODY_RENEW_CERT="$TMP_DIR"/body_renew_cert.xml
RESP_RENEW_CERT="$TMP_DIR"/resp_renew_cert.xml

WORKSPACE_ID=""
AGENT_GUID=""
LOG_FACILITY=local0
CERTIFICATE_UPDATE_ENDPOINT=""
VERBOSE=0

usage()
{
    echo "Maintenance tool for OMS:"
    echo "Onboarding:"
    echo "$0 -w <workspace id> -s <shared key>" >& 2
    echo
    echo "Heartbeat:"
    echo "$0 -b" >& 2
    echo
    echo "Renew certificates:"
    echo "$0 -r" >& 2
    exit 1
}

check_user()
{
    if [ `id -un` != "omsagent" ]; then
        log_error "This script must be run as the omsagent user."
        exit 1
    fi
}

save_config()
{
    #Save configuration
    echo WORKSPACE_ID=$WORKSPACE_ID > $CONF_FILENAME
    echo AGENT_GUID=$AGENT_GUID >> $CONF_FILENAME
    echo LOG_FACILITY=$LOG_FACILITY >> $CONF_FILENAME
    echo CERTIFICATE_UPDATE_ENDPOINT=$CERTIFICATE_UPDATE_ENDPOINT >> $CONF_FILENAME
}

load_config()
{
    if [ ! -e "$CONF_FILENAME" ]; then
        log_error "Missing configuration file : $CONF_FILENAME"
        exit 1
    fi

    . "$CONF_FILENAME"

    if [ -z "$WORKSPACE_ID" -o -z "$AGENT_GUID" ]; then
        log_error "Missing required field from configuration file: $CONF_FILENAME"
        exit 1
    fi
}

cleanup()
{
    rm "$HEADER_ONBOARD" "$BODY_ONBOARD" "$RESP_ONBOARD" > /dev/null 2>&1 || true
    rm "$BODY_HEARTBEAT" "$RESP_HEARTBEAT" > /dev/null 2>&1 || true
    rm "$BODY_RENEW_CERT" "$RESP_RENEW_CERT" > /dev/null 2>&1 || true
    [ "$ONBOARD_FROM_FILE" = "1" ] && rm "$FILE_ONBOARD" > /dev/null 2>&1 || true
}

log_info()
{
    echo -e "info\t$1"
    logger -i -p "$LOG_FACILITY".info -t omsagent "$1"
}

log_error()
{
    echo -e "error\t$1"
    logger -i -p "$LOG_FACILITY".err -t omsagent "$1"
}

parse_args()
{
    local OPTIND opt

    while getopts "h?s:w:brv" opt; do
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
        esac
    done
    shift $((OPTIND-1))

    if [ "$@ " != " " ]; then
        log_error "Parsing error: '$@' is unparsed"
        usage
    fi

    if [ "$VERBOSE" = "1" ]; then
        log_info "Workspace ID:  $WORKSPACE_ID"
        log_info "Shared key:    $SHARED_KEY"
    else
        # Suppress curl output
        CURL_VERBOSE=-s
    fi

    # We need Workspace ID and the shared key (Primary or secondary key, doesn't matter)
    if [ "$ONBOARDING" = "1" ] && [ -z "$WORKSPACE_ID" -o -z "$SHARED_KEY" ]; then
        log_error "Error: Qualifiers -w and -s are mandatory"
        usage
    fi
}

generate_certs()
{
    # Certifictate Information:
    # CN={workspaceId}, CN={agentId, you can use any GUID on registration}, OU=Microsoft Monitoring Agent, O=Microsoft
    log_info "Generating certificate ..."
    openssl req -subj "/CN=$WORKSPACE_ID/CN=$AGENT_GUID/OU=Microsoft Monitoring Agent/O=Microsoft" -new -newkey \
        rsa:2048 -days 365 -nodes -x509 -sha256 -keyout "$FILE_KEY" -out "$FILE_CRT" > /dev/null 2>&1

    if [ "$?" -ne 0 -o ! -e "$FILE_KEY" -o ! -e "$FILE_CRT" ]; then
        log_error "Error generating certs"
        exit 1
    fi

    # Set safe certificate permissions
    chmod 600 "$FILE_KEY" "$FILE_CRT"
}

onboard()
{
    if [ -z "$WORKSPACE_ID" -o -z "$SHARED_KEY" ]; then
        log_error "Missing Wokspace ID or Shared Key information for onboarding"
        exit 1
    fi

    AGENT_GUID=`uuidgen`
    generate_certs

    if [ "$VERBOSE" = "1" ]; then
        log_info "Private Key stored in:   $FILE_KEY"
        log_info "Public Key stored in:    $FILE_CRT"
        # Public key can be verified with a command like:  openssl x509 -text -in oms.crt
    fi

    #
    # Generate the request header and body
    #

    # Generate the body first so we can compute a SHA256 on the body

    REQ_DATE=`date +%Y-%m-%dT%T.%N%:z`
    CERT_SERVER=`cat $FILE_CRT | awk 'NR>2 { print line } { line = $0 }'`
    echo '<?xml version="1.0"?>' > $BODY_ONBOARD
    echo '<AgentTopologyRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://schemas.microsoft.com/WorkloadMonitoring/HealthServiceProtocol/2014/09/">' >> $BODY_ONBOARD
    echo "   <FullyQualfiedDomainName>`hostname -f`</FullyQualfiedDomainName>" >> $BODY_ONBOARD
    echo "   <EntityTypeId>$AGENT_GUID</EntityTypeId>" >> $BODY_ONBOARD
    echo "   <AuthenticationCertificate>${CERT_SERVER}</AuthenticationCertificate>" >> $BODY_ONBOARD
    echo "</AgentTopologyRequest>" >> $BODY_ONBOARD

    CONTENT_HASH=`openssl sha256 $BODY_ONBOARD | awk '{print $2}' | xxd -r -p | base64`

    # Key decode might be a problem with shell escape characters ...
    KEY_DECODED=`echo $SHARED_KEY | base64 -d`
    AUTHORIZATION_KEY=`echo -en "$REQ_DATE\n$CONTENT_HASH\n" | openssl dgst -sha256 -hmac "$KEY_DECODED" -binary | openssl enc -base64`
    echo "x-ms-Date: $REQ_DATE" > $HEADER_ONBOARD
    echo "x-ms-version: August, 2015" >> $HEADER_ONBOARD
    #echo "x-ms-SHA256_Content: $CONTENT_HASH" >> $HEADER_ONBOARD
    echo "Authorization: $WORKSPACE_ID; $AUTHORIZATION_KEY" >> $HEADER_ONBOARD

    if [ $VERBOSE -ne 0 ]; then
        echo
        echo "Generated request:"
        cat $HEADER_ONBOARD
        echo
        cat $BODY_ONBOARD
    fi

    # Send the request to the registration server
    # TODO Save the GUID to a file along with the <ManagementGroupId> from the response

    RET_CODE=`curl --header "x-ms-Date: $REQ_DATE" \
        --header "x-ms-version: August, 2014" \
        --header "x-ms-SHA256_Content: $CONTENT_HASH" \
        --header "Authorization: $WORKSPACE_ID; $AUTHORIZATION_KEY" \
        --header "User-Agent: omsagent 0.5" \
        --insecure \
        --data-binary @$BODY_ONBOARD \
        --cert "$FILE_CRT" --key "$FILE_KEY" \
        --output "$RESP_ONBOARD" $CURL_VERBOSE \
        --write-out "%{http_code}\n" \
        https://${WORKSPACE_ID}.oms.${URL_TLD}.com/AgentService.svc/LinuxAgentTopologyRequest`

    if [ "$RET_CODE" = "200" ]; then
        log_info "Onboarding success"
    else
        log_error "Error onboarding. HTTP code $RET_CODE"
        return 1
    fi

    save_config
    return 0
}

heartbeat()
{
    load_config

    # Generate the request body
    CERT_SERVER=`cat "$FILE_CRT" | awk 'NR>2 { print line } { line = $0 }'`
    echo '<?xml version="1.0"?>' > $BODY_HEARTBEAT
    echo '<AgentTopologyRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://schemas.microsoft.com/WorkloadMonitoring/HealthServiceProtocol/2014/09/">' >> $BODY_HEARTBEAT
    echo "   <FullyQualfiedDomainName>`hostname -f`</FullyQualfiedDomainName>" >> $BODY_HEARTBEAT
    echo "   <EntityTypeId>$AGENT_GUID</EntityTypeId>" >> $BODY_HEARTBEAT
    echo "   <AuthenticationCertificate>${CERT_SERVER}</AuthenticationCertificate>" >> $BODY_HEARTBEAT
    echo "</AgentTopologyRequest>" >> $BODY_HEARTBEAT

    RET_CODE=`curl --insecure \
        --data-binary @$BODY_HEARTBEAT \
        --cert "$FILE_CRT" --key "$FILE_KEY" \
        --output "$RESP_HEARTBEAT" $CURL_VERBOSE \
        --write-out "%{http_code}\n" \
        https://${WORKSPACE_ID}.oms.${URL_TLD}.com/AgentService.svc/LinuxAgentTopologyRequest`

    if [ "$RET_CODE" = "200" ]; then
        # Extract the certificate update endpoint from the server response
        ENDPOINT_TAG=`grep -o "<CertificateUpdateEndpoint.*CertificateUpdateEndpoint>" $RESP_HEARTBEAT`
        CERTIFICATE_UPDATE_ENDPOINT=`echo $ENDPOINT_TAG | grep -o https.*RenewCertificate`

        if [ -z "$CERTIFICATE_UPDATE_ENDPOINT" ]; then
            log_error "Could not extract the update certificate endpoint."
            return 1
        fi

        log_info "Heartbeat success"

        # Save the current certificate endpoint url
        save_config

        # Check in the response if the certs should be renewed
        UPDATE_ATTR=`echo "$ENDPOINT_TAG" | grep -oP "updateCertificate=\"((true|false))\""`
        if [ -z "UPDATE_ATTR" ]; then
            log_error "Could not find the updateCertificate tag in the heartbeat response"
            return 1
        fi

        if echo "$UPDATE_ATTR" | grep "true"; then
            renew_cert
        fi
    else
        log_error "Error sending the heartbeat. HTTP code $RET_CODE"
        return 1
    fi
}

renew_cert()
{
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

    RET_CODE=`curl --insecure \
    --data-binary @$BODY_RENEW_CERT \
    --cert "$FILE_CRT".old --key "$FILE_KEY".old \
    --output "$RESP_RENEW_CERT" $CURL_VERBOSE \
    --write-out "%{http_code}\n" \
    "$CERTIFICATE_UPDATE_ENDPOINT"`

    if [ "$RET_CODE" = "200" ]; then
        # Do one heartbeat for the server to acknowledge the change
        heartbeat

        if [ $? -eq 0 ]; then
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

main()
{
    if [ $# -eq 0 ]; then
        # Allow onboarding params to be loaded from a file
        # The file contains at least these two lines :
        # WORKSPACE_ID="[...]"
        # SHARED_KEY="[...]"
        # and an optional line:
        # URL_TLD=int2.microsoftatlanta-int
        if [ -r "$FILE_ONBOARD" ]; then
            log_info "Reading onboarding params form : $FILE_ONBOARD"
            . "$FILE_ONBOARD"
            ONBOARDING=1
            ONBOARD_FROM_FILE=1
        else
            usage
        fi
    fi

    check_user
    parse_args $@

    if [ ! -d "$TMP_DIR" ]; then
        mkdir -p "$TMP_DIR"
    fi

    [ "$ONBOARDING" = "1" ] && (onboard || exit 1)
    [ "$HEARTBEAT"  = "1" ] && (heartbeat || exit 1)
    [ "$RENEW_CERT" = "1" ] && (renew_cert || exit 1)
    cleanup
    exit 0
}

main $@
