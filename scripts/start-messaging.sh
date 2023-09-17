#!/usr/bin/env -S /bin/bash
set -e

while [ ! -e /opt/tak/firstrun.done ]; do
    echo "Waiting for firstrun.sh to complete..."
    sleep 5
done

TR=/opt/tak
CONFIG=${TR}/data/CoreConfig.xml

# (re-)Create config
echo "(Re-)Creating config"
cat /opt/templates/CoreConfig.tpl | gomplate >${CONFIG}
# make sure it's in tak root too
cp ${CONFIG} /opt/tak/

# Change to workdir
cd ${TR}

# This will set bunch of variables
. ./setenv.sh

# Start the processes
echo "Starting TAK Messaging"
java -jar -Xmx${MESSAGING_MAX_HEAP}m -Dspring.profiles.active=messaging takserver.war
