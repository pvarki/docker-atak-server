#!/usr/bin/env -S /bin/bash
set -e

TR=/opt/tak
CONFIG=${TR}/data/CoreConfig.xml

# (re-)Create config
echo "(Re-)Creating config"
cat /opt/templates/CoreConfig.tpl | gomplate >${CONFIG}
# make sure it's in tak root too
cp ${CONFIG} ${TR}

# Symlink the certs coming from Volumes
if [[ ! -L "${TR}/certs"  ]];then
  mv ${TR}/certs ${TR}/certs.orig
  ln -s "${TR}/data/certs/" "${TR}/certs"
fi

# Symlink the log directory coming from Volumes
if [[ ! -L "${TR}/logs"  ]];then
  mv ${TR}/logs ${TR}/logs.orig
  ln -s "${TR}/data/logs/" "${TR}/logs"
fi

# Change to workdir
cd ${TR}

# This will set bunch of variables
. ./setenv.sh

# Start the right process
if [ $1 = "messaging" ]; then
    echo "Starting TAK Messaging"
    java -jar -Xmx${MESSAGING_MAX_HEAP}m -Dspring.profiles.active=messaging,consolelog takserver.war
elif [ $1 = "api" ]; then
    echo "Starting TAK API"
    java -jar -Xmx${API_MAX_HEAP}m -Dspring.profiles.active=api,consolelog -Dkeystore.pkcs12.legacy takserver.war
elif [ $1 = "retention" ]; then
    echo "Starting TAK API"
    java -jar -Xmx${RETENTION_MAX_HEAP}m takserver-retention.jar
elif [ $1 = "pm" ]; then
    echo "Starting TAK Plugin Manager"
    java -jar -Xmx${PLUGIN_MANAGER_MAX_HEAP}m -Dloader.path=WEB-INF/lib-provided,WEB-INF/lib,WEB-INF/classes,file:lib/ takserver-pm.jar
else
  echo "Please provide right TAK component: messaging, api or pm"
fi
