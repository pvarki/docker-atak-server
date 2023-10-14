#!/usr/bin/env -S /bin/bash
set -e
set -x
TR=/opt/tak
CR=${TR}/certs
CONFIG=${TR}/data/CoreConfig.xml

SETUP_CERTS_USING_MANIFEST="${SETUP_CERTS_USING_MANIFEST:-no}"
RM_LOCAL_API_HOST="${RM_LOCAL_API_HOST:-http://tak_rmapi:8000}"
RM_LOCAL_API_HEALTCHECK_URL="${RM_LOCAL_API_HEALTCHECK_URL:-http://tak_rmapi:8000/api/v1/healthcheck}"
RM_STARTUP_CERTS_LOCAL_FOLDER="${RM_STARTUP_CERTS_LOCAL_FOLDER:-/opt/tak/data/certs/files}"
TAK_SERVER_KEY_FILENAME="${TAK_SERVER_KEY_FILENAME:-tak-server-key.pem}"
TAK_SERVER_CERT_FILENAME="${TAK_SERVER_CERT_FILENAME:-tak-server.pem}"
TAKSERVER_CERT_PASS="${TAKSERVER_CERT_PASS:-Salakala123Porakoira123}"
RM_CERT_CHAIN_FILENAME="${RM_CERT_CHAIN_FILENAME:-tak-server-bundle.pem}"
RM_CERT_ROOT_FILENAME="${RM_CERT_ROOT_FILENAME:-tak-server-root.pem}"

if [[ "${SETUP_CERTS_USING_MANIFEST}" == "yes" ]];then
   echo "Running certificate setup using RM certs..."
   # Checks to figure out if the tak has been initialized already.
  if [[ -f /opt/tak/data/certs/files/truststore-root.jks ]]; then
    echo "truststore-root.jks found. Assuming tak has been initialized already."
    exit 0
  fi

  # Wait for the local RM api to come up
  MAX_ATTEMPTS=240
  HEALTHCHECK_OK="no"
  set +e
  for i in $(seq 1 $MAX_ATTEMPTS);
  do
    RESPONSE_CODE=$(curl -XGET -s -o /dev/null -I -w "%{http_code}" "$RM_LOCAL_API_HEALTCHECK_URL")

    if [[ "$RESPONSE_CODE" == "200" ]]; then
      echo "RM healthcheck success. Moving on..."
      HEALTHCHECK_OK="ok"
      break
    fi
    echo "RM healthcheck '${RESPONSE_CODE}' != 200. Waiting '${RM_LOCAL_API_HEALTCHECK_URL}' ... $i/$MAX_ATTEMPTS"

    sleep 20
  done
  set -e

  # Exit 1 if healthcheck failed
  if [[ "${HEALTHCHECK_OK}" != "ok" ]]; then
    echo "ERROR. All healthchecks failed.. Giving up..."
    exit 1
  fi

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

  mkdir -p /opt/tak/data/certs/files
  pushd ${RM_STARTUP_CERTS_LOCAL_FOLDER} >> /dev/null


  # Create takserver.p12 using certificates from RM
  openssl pkcs12 -export -out takserver.p12 -inkey "${TAK_SERVER_KEY_FILENAME}" -in "${TAK_SERVER_CERT_FILENAME}" -name "${TAK_SERVER_HOSTNAME}" -passin pass:${TAK_SERVER_KEY_PASSPHRASE} -passout pass:${TAKSERVER_CERT_PASS}

  # Print some debug info out of takserver.p12 if needed
  # openssl pkcs12 -info -in takserver.p12 -passin pass:${TAKSERVER_CERT_PASS}

  # Create the Java keystore and import our PKCS12 for our TAK Server. I guess this will be the "server certificate" used by java process..
  keytool -importkeystore -srcstoretype PKCS12 -destkeystore takserver.jks -srckeystore takserver.p12 -alias "${TAK_SERVER_HOSTNAME}" -srcstorepass "${TAKSERVER_CERT_PASS}" -deststorepass "${TAKSERVER_CERT_PASS}" -destkeypass "${TAKSERVER_CERT_PASS}"

  # Crate trust store, all the trusted CA/root certificates are dumped here. Keytool should accept certs either one by one or as a chain. -alias needs to be unique for all imports
  ALIAS=$(openssl x509 -noout -subject -in "${RM_CERT_CHAIN_FILENAME}" |md5sum | cut -d" " -f1)
  keytool -noprompt -import -trustcacerts -file "${RM_CERT_CHAIN_FILENAME}" -alias $ALIAS -keystore takserver-truststore.jks -storepass ${TAKSERVER_CERT_PASS}

  # ca_chain.pem from /ca_public
  ALIAS=$(openssl x509 -noout -subject -in "ca_chain.pem" |md5sum | cut -d" " -f1)
  keytool -noprompt -import -trustcacerts -file "ca_chain.pem" -alias $ALIAS -keystore takserver-truststore.jks -storepass ${TAKSERVER_CERT_PASS}
  # ca_chain.pem from /ca_public
  ALIAS=$(openssl x509 -noout -subject -in "miniwerk_ca.pem" |md5sum | cut -d" " -f1)
  keytool -noprompt -import -trustcacerts -file "miniwerk_ca.pem" -alias $ALIAS -keystore takserver-truststore.jks -storepass ${TAKSERVER_CERT_PASS}

  # fed-truststore.jks is needed, copy takserver-truststore.jks
  # TODO what are the names of truststores that we actually need???
  cp -v /opt/tak/data/certs/files/takserver-truststore.jks /opt/tak/data/certs/files/fed-truststore.jks
  cp -v /opt/tak/data/certs/files/takserver-truststore.jks /opt/tak/data/certs/files/truststore-root.jks

  popd >> /dev/null

  chmod -R 777 ${TR}/data/

  echo "Wait for postgres"
  WAITFORIT_TIMEOUT=60 /usr/bin/wait-for-it.sh ${POSTGRES_ADDRESS}:5432 -- true
  echo "Init db"
  java -jar ${TR}/db-utils/SchemaManager.jar -url jdbc:postgresql://${POSTGRES_ADDRESS}:5432/${POSTGRES_DB} -user ${POSTGRES_USER} -password ${POSTGRES_PASSWORD} upgrade

  exit 0
fi

#
# After this line is the "stand alone" part. This shouldn't need the RM integrations etc...
#

# Remove hardcoded country code
sed -i.orig "s/COUNTRY=US/COUNTRY=\${COUNTRY}/g" ${CR}/cert-metadata.sh
# Override some distribution scripts outright since doing it with sed is too painful
if [[ ! "/opt/scripts/makeCert.sh" ]];then
  mv /opt/scripts/makeCert.sh ${CR}/
fi


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
java -jar ${TR}/db-utils/SchemaManager.jar -url jdbc:postgresql://${POSTGRES_ADDRESS}:5432/${POSTGRES_DB} -user ${POSTGRES_USER} -password ${POSTGRES_PASSWORD} upgrade
