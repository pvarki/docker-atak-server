#!/usr/bin/env -S /bin/bash
ser -e
SCRIPT_DIR=`dirname "$0"`
cd $SCRIPT_DIR
cd ../certs
if [ -f "${ADMIN_CERT_NAME}.pem" ]
then
  exit 0
fi
exit 1
