#!/usr/bin/env bash
set -e
TR=/opt/tak
cp /opt/templates/logback-stdout.xml /opt/tak/

# Ensure anything not having the correct config loads certs and saves logs to the volume
# (yes, we do need to re-check at every start)
if [[ ! -L "${TR}/certs"  ]];then
  mv ${TR}/certs ${TR}/certs.orig
  ln -s "${TR}/data/certs/" "${TR}/certs"
fi
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
    exec java -jar -Xmx${MESSAGING_MAX_HEAP}m -Dspring.profiles.active=messaging,consolelog -Dkeystore.pkcs12.legacy takserver.war
elif [ $1 = "config" ]; then
    echo "Starting TAK config"
    exec java -jar -Xmx${CONFIG_MAX_HEAP}m -Dspring.profiles.active=config takserver.war
elif [ $1 = "api" ]; then
    echo "Starting TAK API"
    # TAK applies CoreConfig keystore overrides only to additional connectors.
    # Its primary HTTPS connector reads Spring's SSL properties instead.
    export SERVER_SSL_KEY_STORE="${TAK_HTTPS_KEYSTORE_FILENAME:-/opt/tak/data/certs/files/takserver-https.jks}"
    exec java -jar -Xmx${API_MAX_HEAP}m -Dspring.profiles.active=api,consolelog -Dkeystore.pkcs12.legacy takserver.war
elif [ $1 = "retention" ]; then
    echo "Starting TAK Retention"
    exec java -jar -Xmx${RETENTION_MAX_HEAP}m takserver-retention.jar
elif [ $1 = "pm" ]; then
    echo "Starting TAK Plugin Manager"
    exec java -jar -Xmx${PLUGIN_MANAGER_MAX_HEAP}m -Dloader.path=WEB-INF/lib-provided,WEB-INF/lib,WEB-INF/classes,file:lib/ takserver-pm.jar
else
  echo "Please provide right TAK component: messaging, config, api, retention or pm"
fi
