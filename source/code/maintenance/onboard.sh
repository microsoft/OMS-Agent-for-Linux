#!/usr/bin/env sh

set -e

#
# Certifictate Information:
#
# O=Microsoft, OU=Microsoft Monitoring Agent, CN={agentId, you can use any GUID on registration}, CN={workspaceId}

# Request body should use XmlSerializer (System.Xml.Serialization, System.Xml.dll) to
# serialize the object of class AgentTopologyRequest
#   Definition in: \Main\Online\OMS\Product\Service\AgentConnectorSchema.cs

#
# Parse the arguments
#
# We need Workspace ID and the shared key (Primary or secondary key, doesn't matter)
#

# Working workspace / key combo for production environment
#bash -x onboard.sh -s dFUjETbH2q6nqiRCw7iiVI8l+Yzj7KQ0Ry5zicKU5zeSm5GNFE9/IvkqGFSa1PRjuElNPIGNB8VJVQuzR0js5w== -w 15b1d09f-7870-457d-818e-7aa0d75d7a8e

usage()
{
    echo "$0 -w <workspace id> -s <shared key>" >& 2
    echo "  -s:   Shared key" >& 2
    echo "  -v:   Verbose output" >& 2
    echo "  -w:   Workspace ID" >& 2

    exit 1
}

OPTIND=1

WORKSPACE_ID=""
SHARED_KEY=""
VERBOSE=0
FILE_KEY=./oms.key
FILE_CRT=./oms.crt
TMP_DIR=tmp
FILENAME_CURL_RETURN="$TMP_DIR"/oms-onboard-curl.out
URL_TLD=opinsights.azure
# For testing / debugging server side
# URL_TLD=int2.microsoftatlanta-int

if [ ! -d "$TMP_DIR" ]; then
    mkdir -p "$TMP_DIR"
fi

while getopts "h?s:vw:" opt; do
    case "$opt" in
    h|\?)
        usage
        ;;
    s)
        SHARED_KEY=$OPTARG
        ;;
    v)
        VERBOSE=1
        ;;
    w)
        WORKSPACE_ID=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

if [ "$@ " != " " ]; then
    echo "Parsing error: '$@' is unparsed" >& 2
    echo "" >& 2
    usage
fi

if [ $VERBOSE -ne 0 ]; then
    echo "Workspace ID:  $WORKSPACE_ID"
    echo "Shared key:    $SHARED_KEY"
fi

if [ -z "$WORKSPACE_ID" -o -z "$SHARED_KEY" ]; then
    echo "Qualifiers -w and -s are mandatory" >& 2
    usage
fi

#
# Generate a certificate subject of:
#
# O=Microsoft, OU=Microsoft Monitoring Agent, CN={agentId, you can use any GUID on registration}, CN={workspaceId}
#

echo "Generating certificate ..."
AGENT_GUID=`uuidgen`
openssl req -subj "/CN=$WORKSPACE_ID/CN=$AGENT_GUID/OU=Microsoft Monitoring Agent/O=Microsoft" -new -newkey rsa:2048 -days 365 -nodes -x509 -sha256 -keyout "$FILE_KEY" -out "$FILE_CRT"

if [ "$?" -ne 0 -o ! -e "$FILE_KEY" -o ! -e "$FILE_CRT" ]; then
    # TODO add error logging
    echo "Error generating certs" 1>&2
    exit 1
fi

# Set safe certificate permissions
chmod 600 "$FILE_KEY" "$FILE_CRT"

CERT_PRIVATE=`cat $FILE_KEY | awk 'NR>2 { print line } { line = $0 }'`
CERT_SERVER=`cat $FILE_CRT | awk 'NR>2 { print line } { line = $0 }'`

echo "Private Key stored in:   $FILE_KEY"
echo "Public Key stored in:    $FILE_CRT"
echo
echo "Public key can be verified with a command like:  openssl x509 -text -in oms.crt"

#
# Generate the request header and body
#

REQ_FILENAME_HEADER="$TMP_DIR"/oms-onboard-hdr.out
REQ_FILENAME_BODY="$TMP_DIR"/oms-onboard-body.out

# Generate the body first so we can compute a SHA256 on the body

REQ_DATE=`date +%Y-%m-%dT%T.%N%:z`

echo '<?xml version="1.0"?>' > $REQ_FILENAME_BODY
echo '<AgentTopologyRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://schemas.microsoft.com/WorkloadMonitoring/HealthServiceProtocol/2014/09/">' >> $REQ_FILENAME_BODY
echo "   <FullyQualfiedDomainName>`hostname -f`</FullyQualfiedDomainName>" >> $REQ_FILENAME_BODY
echo "   <EntityTypeId>$AGENT_GUID</EntityTypeId>" >> $REQ_FILENAME_BODY
echo "   <AuthenticationCertificate>${CERT_SERVER}</AuthenticationCertificate>" >> $REQ_FILENAME_BODY
echo "</AgentTopologyRequest>" >> $REQ_FILENAME_BODY

CONTENT_HASH=`openssl sha256 $REQ_FILENAME_BODY | awk '{print $2}' | xxd -r -p | base64`

# Key decode might be a problem with shell escape characters ...
KEY_DECODED=`echo $SHARED_KEY | base64 -d`
AUTHORIZATION_KEY=`echo -en "$REQ_DATE\n$CONTENT_HASH\n" | openssl dgst -sha256 -hmac "$KEY_DECODED" -binary | openssl enc -base64`
echo "x-ms-Date: $REQ_DATE" > $REQ_FILENAME_HEADER
echo "x-ms-version: August, 2015" >> $REQ_FILENAME_HEADER
echo "x-ms-SHA256_Content: $CONTENT_HASH" >> $REQ_FILENAME_HEADER
echo "Authorization: $WORKSPACE_ID; $AUTHORIZATION_KEY" >> $REQ_FILENAME_HEADER

if [ $VERBOSE -ne 0 ]; then
    echo
    echo "Generated request:"
    cat $REQ_FILENAME_HEADER
    echo
    cat $REQ_FILENAME_BODY
fi

#
# Send the request to the registration server
#
# Save the GUID to a file along with the <ManagementGroupId> from the response
# Registration Server (for now, anyways):
#   https://${WORKSPACE_ID}.oms.int2.microsoftatlanta-int.com/AgentService.svc/AgentTopologyRequest

curl --header "x-ms-Date: $REQ_DATE" \
    --header "x-ms-version: August, 2014" \
    --header "x-ms-SHA256_Content: $CONTENT_HASH" \
    --header "Authorization: $WORKSPACE_ID; $AUTHORIZATION_KEY" \
    --header "User-Agent: omsagent 0.5" \
    --insecure \
    --data-binary @$REQ_FILENAME_BODY \
    --cert "$FILE_CRT" --key "$FILE_KEY" \
    --output "$TMP_DIR/oms-onboard.out" -v \
    --write-out "%{http_code}\n" \
    https://${WORKSPACE_ID}.oms.${URL_TLD}.com/AgentService.svc/AgentTopologyRequest > "$FILENAME_CURL_RETURN"

RET_CODE=`cat $FILENAME_CURL_RETURN`
echo "HTTP return code : $RET_CODE"

if [ "$RET_CODE" != "200" ]; then
    echo "Error during the onboarding request" 1>&2
    exit 1
fi

#Save configuration
CONF_FILENAME=oms.conf
echo WORKSPACE_ID=$WORKSPACE_ID > $CONF_FILENAME
echo AGENT_GUID=$AGENT_GUID >> $CONF_FILENAME
echo FILE_KEY=$FILE_KEY >> $CONF_FILENAME
echo FILE_CRT=$FILE_CRT >> $CONF_FILENAME
echo TMP_DIR=$TMP_DIR >> $CONF_FILENAME
echo URL_TLD=$URL_TLD >> $CONF_FILENAME

#
# Clean up
#
cd "$TMP_DIR"
# rm $REQ_FILENAME_HEADER $REQ_FILENAME_BODY $FILENAME_CURL_RETURN

exit 0
