#!/usr/bin/env sh

# This script is used to periodically renew the certificates
# It requires the output of heartbeat (TMP_DIR/oms-heartbeat.out) to determine if the certs should be renewed

set -e

FILE_CONF=./oms.conf

. "$FILE_CONF"
if [ -z "$WORKSPACE_ID" -o -z "$AGENT_GUID" -o -z "$FILE_CRT" -o -z "$FILE_KEY" \
    -o -z "$TMP_DIR" ]; then
    echo "Missing required fields configuration : $FILE_CONF" 1>&2
    exit 1
fi

FILENAME_CURL_RETURN="$TMP_DIR"/oms-renew-cert-curl.out

# Read the CertificateUpdateEndpoint tag from the server response to determine if
# certs should be regenerated
ENDPOINT_TAG=`grep -o "<CertificateUpdateEndpoint.*CertificateUpdateEndpoint>" $TMP_DIR/oms-heartbeat.out`
UPDATE_ATTR=`echo "$ENDPOINT_TAG" | grep -oP "updateCertificate=\"((true|false))\""`

if [ "$1" = "-f" ] || echo "$UPDATE_ATTR" | grep "true"; then
    echo "Renewing the certificates"

    UPDATE_URL=`echo $ENDPOINT_TAG | grep -o https.*RenewCertificate`
    if [ -z "$UPDATE_URL" ]; then
        echo "Error : could not extract the update certificate endpoint." 1>&2
        exit 1
    fi

    #Create new tmp certs
    openssl req -subj "/CN=$WORKSPACE_ID/CN=$AGENT_GUID/OU=Microsoft Monitoring Agent/O=Microsoft" -new -newkey rsa:2048 -days 365 -nodes -x509 -sha256 -keyout "$TMP_DIR/$FILE_KEY" -out "$TMP_DIR/$FILE_CRT"

    # Set safe certificate permissions
    chmod 600 "$TMP_DIR/$FILE_KEY" "$TMP_DIR/$FILE_CRT"

    REQ_FILENAME_BODY="$TMP_DIR/oms-renew-cert-body.out"
    CERT_SERVER=`cat "$TMP_DIR/$FILE_CRT" | awk 'NR>2 { print line } { line = $0 }'`
    echo '<?xml version="1.0"?>' > $REQ_FILENAME_BODY
    echo '<CertificateUpdateRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://schemas.microsoft.com/WorkloadMonitoring/HealthServiceProtocol/2014/09/">' >> $REQ_FILENAME_BODY
    echo "   <NewCertificate>${CERT_SERVER}</NewCertificate>" >> $REQ_FILENAME_BODY
    echo "</CertificateUpdateRequest>" >> $REQ_FILENAME_BODY

    curl --insecure \
    --data-binary @$REQ_FILENAME_BODY \
    --cert "$FILE_CRT" --key "$FILE_KEY" \
    --output "$TMP_DIR/oms-renew-cert.out" -v \
    --write-out "%{http_code}\n" \
    "$UPDATE_URL" > "$FILENAME_CURL_RETURN"

    RET_CODE=`cat $FILENAME_CURL_RETURN`
    echo "HTTP return code : $RET_CODE"

    if [ "$RET_CODE" -eq "200" ]; then
        echo "renew sucess"
        # Save old certs
        mv "$FILE_CRT" "$FILE_CRT".old
        mv "$FILE_KEY" "$FILE_KEY".old

        # Overwrite old certs with the new ones
        mv "$TMP_DIR/$FILE_CRT" "$FILE_CRT"
        mv "$TMP_DIR/$FILE_KEY" "$FILE_KEY"

        # Do one heartbeat for the server to acknowledge the change
        ./heartbeat.sh

        if [ $? -eq 0 ]; then
            echo "Certificates successfully renewed"
            rm "$FILE_CRT".old "$FILE_KEY".old
        else
            echo "Error renewing certificate. Restoring old certs." 1>&2
            # Restore old certs
            mv "$FILE_CRT".old "$FILE_CRT"
            mv "$FILE_KEY".old "$FILE_KEY"
            exit 1
        fi
    else
        # TODO Add error logging
        echo "Error code $RET_CODE returned by server" 1>&2
        exit 1
    fi
else
    echo "No need to renew certs"
fi