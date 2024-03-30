#!/usr/bin/env -S /bin/bash
set -e
TR=/opt/tak
CONFIG=${TR}/data/CoreConfig.xml

cd ${TR}
. ./setenv.sh


# First set user to "jail" group and then actually delete the user. Removing the user doesn't make the client disconnect the active session.
TAKCL_CORECONFIG_PATH="${CONFIG}" java -jar /opt/tak/utils/UserManager.jar certmod -g jail "/opt/tak/data/certs/files/${USER_CERT_NAME}.pem"
TAKCL_CORECONFIG_PATH="${CONFIG}" java -jar /opt/tak/utils/UserManager.jar certmod -D "/opt/tak/data/certs/files/${USER_CERT_NAME}.pem"
