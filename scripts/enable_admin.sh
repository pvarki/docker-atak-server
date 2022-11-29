#!/usr/bin/env -S /bin/bash
set -e
TR=/opt/tak
CONFIG=${TR}/data/CoreConfig.xml

# Wait for server start
WAITFORIT_TIMEOUT=30 /usr/bin/wait-for-it.sh ${POSTGRES_ADDRESS}:5432 -- true
WAITFORIT_TIMEOUT=60 /usr/bin/wait-for-it.sh localhost:8089 -- true

cd ${TR}
. ./setenv.sh
TAKCL_CORECONFIG_PATH="${CONFIG}" java -jar /opt/tak/utils/UserManager.jar certmod -A "/opt/tak/certs/files/${ADMIN_CERT_NAME}.pem"
