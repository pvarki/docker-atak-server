#!/usr/bin/env -S /bin/bash
set -e
TR=/opt/tak
CONFIG=${TR}/data/CoreConfig.xml

cd ${TR}
. ./setenv.sh
set -x
TAKCL_CORECONFIG_PATH="${CONFIG}" java -jar /opt/tak/utils/UserManager.jar certmod "/opt/tak/data/certs/files/${USER_CERT_NAME}.pem"
