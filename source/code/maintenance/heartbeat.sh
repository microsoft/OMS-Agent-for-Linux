#!/usr/bin/env sh

# This script periodically pings the oms server and checks if certs must be renewed

set -e
FILE_CONF=./oms.conf

if [ ! -e "$FILE_CONF" ]; then
    echo "Missing configuration file : $FILE_CONF" 1>&2
    # TODO add logging
    exit 1
fi

# Load the configuration by sourcing it. Each line is in the format VAR=VALUE
. "$FILE_CONF"

if [ -z "$AGENT_GUID" -o -z "$FILE_CRT" -o -z "$FILE_KEY" -o -z "TMP_DIR" ]; then
    echo "Missing required fields configuration : $FILE_CONF" 1>&2
    exit 1
fi

REQ_FILENAME_BODY="$TMP_DIR"/oms-heartbeat-body.out
FILENAME_CURL_RETURN="$TMP_DIR"/oms-send-curl.out

# Generate the request body
CERT_SERVER=`cat "$FILE_CRT" | awk 'NR>2 { print line } { line = $0 }'`
echo '<?xml version="1.0"?>' > $REQ_FILENAME_BODY
echo '<AgentTopologyRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://schemas.microsoft.com/WorkloadMonitoring/HealthServiceProtocol/2014/09/">' >> $REQ_FILENAME_BODY
echo "   <FullyQualfiedDomainName>`hostname -f`</FullyQualfiedDomainName>" >> $REQ_FILENAME_BODY
echo "   <EntityTypeId>$AGENT_GUID</EntityTypeId>" >> $REQ_FILENAME_BODY
echo "   <AuthenticationCertificate>${CERT_SERVER}</AuthenticationCertificate>" >> $REQ_FILENAME_BODY
echo "</AgentTopologyRequest>" >> $REQ_FILENAME_BODY


curl --insecure \
    --data-binary @$REQ_FILENAME_BODY \
    --cert "$FILE_CRT" --key "$FILE_KEY" \
    --output "$TMP_DIR/oms-heartbeat.out" -v \
    --write-out "%{http_code}\n" \
    https://${WORKSPACE_ID}.oms.${URL_TLD}.com/AgentService.svc/AgentTopologyRequest > "$FILENAME_CURL_RETURN"

RET_CODE=`cat $FILENAME_CURL_RETURN`
echo "HTTP return code : $RET_CODE"

if [ "$RET_CODE" -eq "200" ]; then
    echo "Heartbeat success"
    # TODO check for renewing certs automatically?
    # ./renew-cert.sh
    exit 0
else
    echo "Error sending the heartbeat. HTTP code $RET_CODE" 1>&2
    # TODO add error logging
    exit 1
fi
