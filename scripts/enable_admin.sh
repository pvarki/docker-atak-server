#!/usr/bin/env -S /bin/bash
set -e
TR=/opt/tak
CONFIG=${TR}/data/CoreConfig.xml
cd ${TR}
. ./setenv.sh

echo "enable_admin: Waiting for TAK server"
WAITFORIT_TIMEOUT=2 /usr/bin/wait-for-it.sh localhost:8089 -- true

echo "enable_admin: Making sure ${ADMIN_CERT_NAME} user is in place"
TAKCL_CORECONFIG_PATH="${CONFIG}" java -jar /opt/tak/utils/UserManager.jar certmod -A -g default "/opt/tak/data/certs/files/${ADMIN_CERT_NAME}.pem"
