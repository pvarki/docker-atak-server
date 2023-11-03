#!/usr/bin/env -S /bin/bash
if [ -f /opt/tak/data/firstrun.done ]
then
  echo "First run already cone"
  exit 0
fi

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

set -x

TAK_SERVER_HOSTNAME="$(cat /pvarki/kraftwerk-init.json | jq -r  .product.dns)"


mkdir -p /opt/tak/data/certs/files
pushd /opt/tak/data/certs/files >> /dev/null

# Create takserver.p12 using certificates from RM
openssl pkcs12 -export -out takserver.p12 \
  -inkey "${TAK_SERVER_KEY_FILENAME}" \
  -in "${TAK_SERVER_CERT_FILENAME}" \
  -name "${TAK_SERVER_HOSTNAME}" \
  -passout pass:${TAKSERVER_KEYSTORE_PASS}

# Create the Java keystore and import takserver.p12
keytool -importkeystore -srcstoretype PKCS12 \
  -destkeystore takserver.jks \
  -srckeystore takserver.p12 \
  -alias "${TAK_SERVER_HOSTNAME}" \
  -srcstorepass "${TAKSERVER_KEYSTORE_PASS}" \
  -deststorepass "${TAKSERVER_KEYSTORE_PASS}" \
  -destkeypass "${TAKSERVER_KEYSTORE_PASS}"

# Crate trust store, all the trusted CA/root certificates are dumped here. Keytool should accept certs either one by one or as a chain. -alias needs to be unique for all imports
ALIAS=$(openssl x509 -noout -subject -in "${RM_CERT_CHAIN_FILENAME}" |md5sum | cut -d" " -f1)
keytool -noprompt -import -trustcacerts \
  -file "${RM_CERT_CHAIN_FILENAME}" \
  -alias $ALIAS \
  -keystore takserver-truststore.jks \
  -storepass ${KEYSTORE_PASS}

if [[ -f "/ca_public/miniwerk_ca.pem" ]];then
  ALIAS=$(openssl x509 -noout -subject -in "/ca_public/miniwerk_ca.pem" |md5sum | cut -d" " -f1)
  keytool -noprompt -import -trustcacerts \
    -file /ca_public/miniwerk_ca.pem \
    -alias $ALIAS \
    -keystore takserver-truststore.jks \
    -storepass ${KEYSTORE_PASS}
fi

# fed-truststore.jks is needed, copy takserver-truststore.jks
# TODO what are the names of truststores that we actually need???
cp -v /opt/tak/data/certs/files/takserver-truststore.jks /opt/tak/data/certs/files/fed-truststore.jks
cp -v /opt/tak/data/certs/files/takserver-truststore.jks /opt/tak/data/certs/files/truststore-root.jks

popd >> /dev/null




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
