#!/usr/bin/env -S /bin/bash
set -e

TR=/opt/tak
export TAKCL_CORECONFIG_PATH=${TR}/data/CoreConfig_${1}.xml # use process specific copy
COMMON_CONFIG_PATH=${TR}/data/CoreConfig.xml  # common path used by various scripts
IGNITE_CONFIG_PATH=${TR}/data/TAKIgniteConfig.xml  # This should be same for everyone
sleep 2

# (re-)Create config
echo "(Re-)Creating CoreConfig"
set -x
gomplate -f /opt/templates/CoreConfig.tpl -o ${COMMON_CONFIG_PATH}  # used by various scripts
# Process specific config
gomplate -f /opt/templates/CoreConfig.tpl -o ${TAKCL_CORECONFIG_PATH}
# make sure it's in tak root too
ln -sf ${TAKCL_CORECONFIG_PATH} ${TR}/CoreConfig.xml
ls -lah ${TR}/CoreConfig.xml
cat ${TR}/CoreConfig.xml

echo "(Re-)Creating IgniteConfig"
gomplate -f /opt/templates/TAKIgniteConfig.tpl -o ${IGNITE_CONFIG_PATH}
ln -sf ${IGNITE_CONFIG_PATH} ${TR}/TAKIgniteConfig.xml
ls -lah ${TR}/TAKIgniteConfig.xml
cat ${TR}/TAKIgniteConfig.xml

echo "Ensuring our logging config is in place (Logback)"
cp /opt/templates/logback-stdout.xml /opt/tak/

set +x

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

# TAK validates every client certificate against the OCSP responder named in its
# AIA extension, and in this deployment that URL is HTTPS. That call goes through
# the JVM truststore, not TAK's own truststore, so without the deployment CA in
# there the responder's TLS certificate is untrusted, the OCSP check throws, and
# netty rejects every mTLS client with "peer not verified" - nothing wrong with
# the client certificate at all. Re-applied on every start; the JVM truststore
# lives in the image layer, not on a volume.
if [[ -d /ca_public ]];then
  for pem in /ca_public/*.pem; do
    grep -q "BEGIN CERTIFICATE" "${pem}" || continue  # /ca_public also holds CRLs
    ALIAS="ca_public_$(basename "${pem}" .pem)"
    keytool -cacerts -storepass changeit -delete -alias "${ALIAS}" >/dev/null 2>&1 || true
    keytool -cacerts -storepass changeit -noprompt -importcert -trustcacerts \
      -alias "${ALIAS}" -file "${pem}" >/dev/null && echo "JVM now trusts ${pem}"
  done
fi

# Change to workdir
cd ${TR}

# This will set bunch of variables
. ./setenv.sh

# Start the right process
if [ $1 = "messaging" ]; then
    echo "Starting TAK Messaging"
    java -jar -Xmx${MESSAGING_MAX_HEAP}m -Dspring.profiles.active=messaging,consolelog -Dkeystore.pkcs12.legacy takserver.war
elif [ $1 = "config" ]; then
    echo "Starting TAK config"
    java -jar -Xmx${CONFIG_MAX_HEAP}m -Dspring.profiles.active=config takserver.war
elif [ $1 = "api" ]; then
    echo "Starting TAK API"
    java -jar -Xmx${API_MAX_HEAP}m -Dspring.profiles.active=api,consolelog -Dkeystore.pkcs12.legacy takserver.war
elif [ $1 = "retention" ]; then
    echo "Starting TAK Retention"
    java -jar -Xmx${RETENTION_MAX_HEAP}m takserver-retention.jar
elif [ $1 = "pm" ]; then
    echo "Starting TAK Plugin Manager"
    java -jar -Xmx${PLUGIN_MANAGER_MAX_HEAP}m -Dloader.path=WEB-INF/lib-provided,WEB-INF/lib,WEB-INF/classes,file:lib/ takserver-pm.jar
else
  echo "Please provide right TAK component: messaging, config, api, retention or pm"
fi
