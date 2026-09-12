#!/usr/bin/env -S /bin/bash
set -euo pipefail
TR=/opt/tak

# CoT and TAK's built-in JWT signer share an RSA identity issued by CFSSL via RMAPI.
TAK_SERVER_KEY_FILENAME="${TAK_SERVER_KEY_FILENAME:-/data/persistent/private/mtlsclient.key}"
TAK_SERVER_CERT_FILENAME="${TAK_SERVER_CERT_FILENAME:-/data/persistent/public/mtlsclient.pem}"
TAK_HTTPS_KEY_FILENAME="${TAK_HTTPS_KEY_FILENAME:-/le_certs/rasenmaeher/privkey.pem}"
TAK_HTTPS_CERT_FILENAME="${TAK_HTTPS_CERT_FILENAME:-/le_certs/rasenmaeher/fullchain.pem}"
TAK_HTTPS_KEYSTORE_FILENAME="${TAK_HTTPS_KEYSTORE_FILENAME:-/opt/tak/data/certs/files/takserver-https.jks}"
TAKSERVER_KEYSTORE_PASS="${TAKSERVER_KEYSTORE_PASS:-takservercertpass}"
RM_CERT_CHAIN_FILENAME="${RM_CERT_CHAIN_FILENAME:-/ca_public/ca_chain.pem}"
KEYSTORE_PASS="${KEYSTORE_PASS:-takcacertpw}"

mkdir -p "${TR}/data/logs" "${TR}/data/certs/files" /data/persistent
if [[ ! -L "${TR}/logs" ]]; then
  ln -f -s "${TR}/data/logs/" "${TR}/logs"
fi
if [[ ! -L "${TR}/certs" ]]; then
  mv "${TR}/certs" "${TR}/certs.orig"
  ln -f -s "${TR}/data/certs/" "${TR}/certs"
fi

TAK_SERVER_HOSTNAME="$(jq -er .product.dns /pvarki/kraftwerk-init.json)"
# Development DNS resolves to loopback; reach the published RMAPI through the host.
if [[ "$(jq -r .rasenmaeher.init.base_uri /pvarki/kraftwerk-init.json)" == *localmaeher.dev.pvarki.fi* ]]; then
  GW_IP="$(getent ahostsv4 host.docker.internal | awk '$2 == "STREAM" {print $1; exit}')"
  test -n "${GW_IP}"
  echo "${GW_IP} localmaeher.dev.pvarki.fi mtls.localmaeher.dev.pvarki.fi" >> /etc/hosts
fi

# Reuse the product identity on restart, including identities created by older takrmapi.
# The manifest's CSR token must never be consumed independently by both containers.
if [[ ! -s /data/persistent/public/mtlsclient.pem ]]; then
  /kw_product_init init --keytype RSA /pvarki/kraftwerk-init.json
fi
openssl rsa -in "${TAK_SERVER_KEY_FILENAME}" -check -noout >/dev/null
if ! openssl verify -CAfile "${RM_CERT_CHAIN_FILENAME}" -purpose sslserver \
    -verify_hostname "${TAK_SERVER_HOSTNAME}" "${TAK_SERVER_CERT_FILENAME}"; then
  # Older product certificates only had clientAuth. Reissue using the same key
  # and mTLS credentials, without consuming the bootstrap token again.
  /kw_product_init renew /pvarki/kraftwerk-init.json
  openssl verify -CAfile "${RM_CERT_CHAIN_FILENAME}" -purpose sslserver \
    -verify_hostname "${TAK_SERVER_HOSTNAME}" "${TAK_SERVER_CERT_FILENAME}"
fi
date -u +"%Y%m%dT%H%M" >/data/persistent/firstrun.done

cert_work="$(mktemp -d "${TR}/data/certs/files/.init-XXXXXX")"
trap 'rm -rf "$cert_work"' EXIT

import_identity() {
  local name="$1" key="$2" certificate="$3" destination="$4"
  # Build fresh stores so stale aliases cannot affect TAK's JWT key selection.
  openssl pkcs12 -export -out "${cert_work}/${name}.p12" \
    -inkey "${key}" -in "${certificate}" -name "${TAK_SERVER_HOSTNAME}" \
    -passout "pass:${TAKSERVER_KEYSTORE_PASS}"
  keytool -noprompt -importkeystore -srcstoretype PKCS12 -deststoretype JKS \
    -destkeystore "${cert_work}/${name}.jks" -srckeystore "${cert_work}/${name}.p12" \
    -alias "${TAK_SERVER_HOSTNAME}" -srcstorepass "${TAKSERVER_KEYSTORE_PASS}" \
    -deststorepass "${TAKSERVER_KEYSTORE_PASS}" -destkeypass "${TAKSERVER_KEYSTORE_PASS}"
  chmod 600 "${cert_work}/${name}.jks"
  mv "${cert_work}/${name}.jks" "${destination}"
}

import_identity cot "${TAK_SERVER_KEY_FILENAME}" "${TAK_SERVER_CERT_FILENAME}" \
  "${TR}/data/certs/files/takserver.jks"
import_identity https "${TAK_HTTPS_KEY_FILENAME}" "${TAK_HTTPS_CERT_FILENAME}" \
  "${TAK_HTTPS_KEYSTORE_FILENAME}"

for ca in root_ca intermediate_ca; do
  keytool -noprompt -importcert -trustcacerts -storetype JKS \
    -file "/ca_public/${ca}.pem" -alias "${ca}" \
    -keystore "${cert_work}/truststore.jks" -storepass "${KEYSTORE_PASS}"
done
# Client identities on TAK and federation connections are issued by CFSSL.
cp "${cert_work}/truststore.jks" "${TR}/data/certs/files/truststore-root.jks"
KEYSTORE_PASS="${KEYSTORE_PASS}" /usr/bin/python3 /opt/scripts/init-fed-truststore.py \
  "${TR}/data/certs/files/fed-truststore.jks" "${TAK_SERVER_CERT_FILENAME}" "${RM_CERT_CHAIN_FILENAME}"
mv "${cert_work}/truststore.jks" "${TR}/data/certs/files/takserver-truststore.jks"

if [[ -f "${TR}/data/firstrun.done" ]]; then
  echo "First run already done, not importing database"
  exit 0
fi

echo "Wait for postgres"
WAITFORIT_TIMEOUT=60 /usr/bin/wait-for-it.sh "${POSTGRES_ADDRESS}:5432" -- true
echo "Init db"
PGPASSWORD="${POSTGRES_PASSWORD}" psql -v ON_ERROR_STOP=1 -h "${POSTGRES_ADDRESS}" \
  -U "${POSTGRES_USER}" "${POSTGRES_DB}" --single-transaction --file /opt/scripts/takdb_base.sql
java -jar "${TR}/db-utils/SchemaManager.jar" \
  -url "jdbc:postgresql://${POSTGRES_ADDRESS}:5432/${POSTGRES_DB}" \
  -user "${POSTGRES_USER}" -password "${POSTGRES_PASSWORD}" upgrade
date -u +"%Y%m%dT%H%M" >"${TR}/data/firstrun.done"
