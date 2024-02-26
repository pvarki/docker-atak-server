#!/usr/bin/env -S /bin/bash
TR=/opt/tak
CR=${TR}/certs

TAK_SERVER_KEY_FILENAME="${TAK_SERVER_KEY_FILENAME:-/le_certs/rasenmaeher/privkey.pem}"
TAK_SERVER_CERT_FILENAME="${TAK_SERVER_CERT_FILENAME:-/le_certs/rasenmaeher/fullchain.pem}"
TAKSERVER_KEYSTORE_PASS="${TAKSERVER_KEYSTORE_PASS:-takservercertpass}"

RM_CERT_CHAIN_FILENAME="${RM_CERT_CHAIN_FILENAME:-/ca_public/ca_chain.pem}"

# Secret to trusted certs java keystore
KEYSTORE_PASS="${KEYSTORE_PASS:-takcacertpw}"

# Symlink the log directory under data dir
if [[ ! -d "${TR}/data/logs" ]];then
  mkdir -p "${TR}/data/logs"
fi
if [[ ! -L "${TR}/logs"  ]];then
  ln -f -s "${TR}/data/logs/" "${TR}/logs"
fi

# Seed initial certificate data if necessary
if [[ ! -d "${TR}/data/certs" ]];then
  mkdir -p "${TR}/data/certs"
fi
# Move original certificate data and symlink to certificate data in data dir
if [[ ! -L "${TR}/certs"  ]];then
  mv ${TR}/certs ${TR}/certs.orig
  ln -f -s "${TR}/data/certs/" "${TR}/certs"
fi

TAK_SERVER_HOSTNAME="$(cat /pvarki/kraftwerk-init.json | jq -r  .product.dns)"


mkdir -p /opt/tak/data/certs/files
pushd /opt/tak/data/certs/files >> /dev/null

openssl list -providers 2>&1 | grep "\(invalid command\|unknown option\)" >/dev/null
if [ $? -ne 0 ] ; then
  echo "Using legacy provider"
  LEGACY_PROVIDER="-legacy"
fi


echo "(re)Add TLS keys to keystore"
# We have to do this pkcs12 song and dance because keytool can't import private keys directly
# Create takserver.p12 using certificates from RM
openssl pkcs12 ${LEGACY_PROVIDER} -export -out takserver.p12 \
  -inkey "${TAK_SERVER_KEY_FILENAME}" \
  -in "${TAK_SERVER_CERT_FILENAME}" \
  -name "${TAK_SERVER_HOSTNAME}" \
  -passout pass:${TAKSERVER_KEYSTORE_PASS}

# Remove the old key (if exists)
keytool -delete \
  -alias "${TAK_SERVER_HOSTNAME}" \
  -keystore takserver.jks \
  -storepass "${TAKSERVER_KEYSTORE_PASS}"
# Create the Java keystore and import takserver.p12
keytool -importkeystore -srcstoretype PKCS12 \
  -destkeystore takserver.jks \
  -srckeystore takserver.p12 \
  -alias "${TAK_SERVER_HOSTNAME}" \
  -srcstorepass "${TAKSERVER_KEYSTORE_PASS}" \
  -deststorepass "${TAKSERVER_KEYSTORE_PASS}" \
  -destkeypass "${TAKSERVER_KEYSTORE_PASS}"

# Put the CA certs one-by-one (can't import full chains in one go) to the truststore
# Remove the old root key (if exists)
keytool -delete \
  -alias "RM_Root" \
  -keystore takserver-truststore.jks \
  -storepass ${KEYSTORE_PASS}
# Add root key
keytool -noprompt -import -trustcacerts \
  -file "/ca_public/root_ca.pem" \
  -alias "RM_Root" \
  -keystore takserver-truststore.jks \
  -storepass ${KEYSTORE_PASS}

# Remove the old intermediate key (if exists)
keytool -delete \
  -alias "RM_Intermediate" \
  -keystore takserver-truststore.jks \
  -storepass ${KEYSTORE_PASS}
# Add intermediate key
keytool -noprompt -import -trustcacerts \
  -file "/ca_public/intermediate_ca.pem" \
  -alias "RM_Intermediate" \
  -keystore takserver-truststore.jks \
  -storepass ${KEYSTORE_PASS}

if [[ -f "/ca_public/miniwerk_ca.pem" ]];then
  # Remove the old key (if exists)
  keytool -delete \
    -alias "MW_Root" \
    -keystore takserver-truststore.jks \
    -storepass ${KEYSTORE_PASS}
  keytool -noprompt -import -trustcacerts \
    -file /ca_public/miniwerk_ca.pem \
    -alias "MW_Root" \
    -keystore takserver-truststore.jks \
    -storepass ${KEYSTORE_PASS}
fi

# fed-truststore.jks is needed, copy takserver-truststore.jks
# TODO what are the names of truststores that we actually need???
cp -v /opt/tak/data/certs/files/takserver-truststore.jks /opt/tak/data/certs/files/fed-truststore.jks
cp -v /opt/tak/data/certs/files/takserver-truststore.jks /opt/tak/data/certs/files/truststore-root.jks

popd >> /dev/null

if [ -f /opt/tak/data/firstrun.done ]
then
  echo "First run already done, not importing database"
  exit 0
fi


set -e
echo "Wait for postgres"
WAITFORIT_TIMEOUT=60 /usr/bin/wait-for-it.sh ${POSTGRES_ADDRESS}:5432 -- true
echo "Init db"
# This requires postgres superuser privileges which we do not want to actually give to tak containers
# java -jar ${TR}/db-utils/SchemaManager.jar -url jdbc:postgresql://${POSTGRES_ADDRESS}:5432/${POSTGRES_DB} -user ${POSTGRES_SUPERUSER} -password ${POSTGRES_SUPER_PASSWORD} upgrade
# First import base SQL file to get base migration state
PGPASSWORD=${POSTGRES_PASSWORD} psql -v ON_ERROR_STOP=1 -h ${POSTGRES_ADDRESS} -U ${POSTGRES_USER} ${POSTGRES_DB} --single-transaction --file /opt/scripts/takdb_base.sql
# Then if there are any un-applied migrations apply them.
java -jar ${TR}/db-utils/SchemaManager.jar -url jdbc:postgresql://${POSTGRES_ADDRESS}:5432/${POSTGRES_DB} -user ${POSTGRES_USER} -password ${POSTGRES_PASSWORD} upgrade

date -u +"%Y%m%dT%H%M" >/opt/tak/data/firstrun.done
