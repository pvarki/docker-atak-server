#!/usr/bin/env -S /bin/bash
set -e
TR=/opt/tak
CONFIG=${TR}/data/CoreConfig.xml

# Wait for server start
echo "enable_admin: Waiting for db"
WAITFORIT_TIMEOUT=30 /usr/bin/wait-for-it.sh ${POSTGRES_ADDRESS}:5432 -- true
echo "enable_admin: Waiting for TAK server"
WAITFORIT_TIMEOUT=60 /usr/bin/wait-for-it.sh localhost:8089 -- true

echo "enable_admin: Making sure ${ADMIN_CERT_NAME} user is in place"
cd ${TR}
. ./setenv.sh
TAKCL_CORECONFIG_PATH="${CONFIG}" java -jar /opt/tak/utils/UserManager.jar certmod -A "/opt/tak/data/certs/files/${ADMIN_CERT_NAME}.pem"
