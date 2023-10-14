#!/usr/bin/env -S /bin/bash
TR=/opt/tak
CR=${TR}/certs
CONFIG=${TR}/data/CoreConfig.xml

set -e

# Remove hardcoded country code
sed -i.orig "s/COUNTRY=US/COUNTRY=\${COUNTRY}/g" ${CR}/cert-metadata.sh
# Override some distribution scripts outright since doing it with sed is too painful
cp /opt/scripts/makeCert.sh ${CR}/

# Seed initial certificate data if necessary
if [[ ! -d "${TR}/data/certs" ]];then
  mkdir -p "${TR}/data/certs"
fi
if [[ -z "$(ls -A "${TR}/data/certs")" ]];then
  echo Copying initial certificate configuration
  cp -R ${TR}/certs/* ${TR}/data/certs/
else
  echo Using existing certificates.
fi

# Move original certificate data and symlink to certificate data in data dir
if [[ ! -L "${TR}/certs"  ]];then
  mv ${TR}/certs ${TR}/certs.orig
  ln -s "${TR}/data/certs/" "${TR}/certs"
fi

# Symlink the log directory
if [[ ! -L "${TR}/certs"  ]];then
  ln -s "${TR}/data/logs/" "${TR}/logs"
fi

cd ${CR}

if [[ ! -f "${CR}/files/root-ca.pem" ]];then
  CAPASS=${CA_PASS} bash makeRootCa.sh --ca-name "${CA_NAME}"
else
  echo Using existing root CA.
fi

if [[ ! -f "${CR}/files/takserver.pem" ]];then
  CAPASS=${CA_PASS} PASS="${TAKSERVER_CERT_PASS}" bash makeCert.sh server takserver
else
  echo Using existing takserver certificate.
fi

if [[ ! -f "${CR}/files/${ADMIN_CERT_NAME}.pem" ]];then
  CAPASS=${CA_PASS} PASS="${ADMIN_CERT_PASS}" bash makeCert.sh client "${ADMIN_CERT_NAME}"
else
  echo Using existing ${ADMIN_CERT_NAME} certificate.
fi

chmod -R 777 ${TR}/data/

echo "Wait for postgres"
WAITFORIT_TIMEOUT=60 /usr/bin/wait-for-it.sh ${POSTGRES_ADDRESS}:5432 -- true
echo "Init db"
java -jar ${TR}/db-utils/SchemaManager.jar -url jdbc:postgresql://${POSTGRES_ADDRESS}:5432/${POSTGRES_DB} -user ${POSTGRES_SUPERUSER} -password ${POSTGRES_SUPER_PASSWORD} upgrade