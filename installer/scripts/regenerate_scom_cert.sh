#!/bin/sh

set -e

SCX_SSL_CONFIG=/opt/microsoft/scx/bin/tools/scxsslconfig
SCOM_CERT_DIR=/etc/opt/microsoft/omsagent/scom/certs
HOSTNAME=""
DOMAIN_NAME=""

usage()
{
    local basename=`basename $0`
    echo "SCOM Certificate Regeneration Utility"
    echo
    echo "Regenerate certificate:"
    echo "$basename [-h <hostname>] [-d <domain name>]"
    echo 
    echo "Help:"
    echo "$basename -?"
}

parse_args()
{
    local OPTIND opt
    while getopts "?h:d:" opt; do
        case "$opt" in
        \?)
            usage
            exit 0
            ;;
        h)
            HOSTNAME=$OPTARG
            ;;
        d)
            DOMAIN_NAME=$OPTARG
            ;;
        esac
    done
    shift $((OPTIND-1))
}

check_user()
{
    if [ `id -u` -ne "0" -a `id -un` != "omsagent" ]; then
        echo "This script must be run as root or as the omsagent user."
        exit 1
    fi
}

regenerate_cert()
{
    echo "Regenerating SCOM certs"
    # Generate client auth cert using scxsslconfig tool.
    $SCX_SSL_CONFIG -c -g $SCOM_CERT_DIR -h "$HOSTNAME" -d "$DOMAIN_NAME"
    if [ $? -ne 0 ]; then
        echo "Error generating certs"
        exit 1
    fi
    # Rename cert/key to more meaningful name
    mv $SCOM_CERT_DIR/omi-host-*.pem $SCOM_CERT_DIR/scom-cert.pem
    mv $SCOM_CERT_DIR/omikey.pem $SCOM_CERT_DIR/scom-key.pem
    rm -f $SCOM_CERT_DIR/omi.pem
    chown omsagent:omiusers $SCOM_CERT_DIR/scom-cert.pem
    chown omsagent:omiusers $SCOM_CERT_DIR/scom-key.pem
}

check_user
parse_args $@
regenerate_cert
