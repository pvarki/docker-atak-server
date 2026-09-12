#!/usr/bin/env bash
set -euo pipefail

scripts="$(cd "$(dirname "$0")/../scripts" && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT
export KEYSTORE_PASS=test-password

for name in root intermediate product; do
  openssl req -new -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -keyout "${workdir}/${name}.key" -out "${workdir}/${name}.pem" \
    -days 1 -subj "/CN=${name}" >/dev/null 2>&1
done
cat "${workdir}/intermediate.pem" "${workdir}/root.pem" > "${workdir}/chain.pem"
# A product fullchain may repeat certificates already supplied in the CA chain.
cat "${workdir}/product.pem" "${workdir}/intermediate.pem" > "${workdir}/identity.pem"
/usr/bin/python3 "${scripts}/init-fed-truststore.py" "${workdir}/fed.jks" \
  "${workdir}/identity.pem" "${workdir}/chain.pem"
keytool -list -rfc -keystore "${workdir}/fed.jks" -storepass:env KEYSTORE_PASS \
  > "${workdir}/listed.pem"
[[ "$(grep -c 'BEGIN CERTIFICATE' "${workdir}/listed.pem")" == 3 ]]
for name in root intermediate product; do
  alias="$(openssl x509 -in "${workdir}/${name}.pem" -noout -fingerprint -sha256 | cut -d= -f2 | tr -d :)"
  keytool -list -alias "${alias}" -keystore "${workdir}/fed.jks" \
    -storepass:env KEYSTORE_PASS >/dev/null
done
cp "${workdir}/fed.jks" "${workdir}/original.jks"
# Existing stores must be untouched, even if credentials or source files change.
KEYSTORE_PASS=different /usr/bin/python3 "${scripts}/init-fed-truststore.py" \
  "${workdir}/fed.jks" /missing/identity.pem /missing/chain.pem
cmp "${workdir}/original.jks" "${workdir}/fed.jks"
echo "PASS: product and both CA certificates imported; existing truststore preserved"
