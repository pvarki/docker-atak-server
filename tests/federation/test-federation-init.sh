#!/usr/bin/env bash
#
# Runs k8s/app-tak/base/scripts/federation-init.sh against stubbed openssl/keytool/curl
# and checks the two things that are silently wrong if they break:
#   - <federation> child order (CoreConfig.xsd: federation-outgoing*, fileFilter, federateCA*)
#   - exactly one side of each pair dials, decided by hostname comparison
#
# No cluster, no network, no dependencies beyond bash and xmllint.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_UNDER_TEST="${REPO}/scripts/federation-init.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

mkdir -p "${TMP}/bin" "${TMP}/ca_public" "${TMP}/fed_certs" "${TMP}/fed_peer_ca" \
         "${TMP}/opt/tak/data/certs/files"

for f in root_ca intermediate_ca; do
  printf -- '-----BEGIN CERTIFICATE-----\n%s\n-----END CERTIFICATE-----\n' "${f}" \
    > "${TMP}/ca_public/${f}.pem"
done
cp "${TMP}/ca_public/root_ca.pem" "${TMP}/fed_certs/tls.crt"
printf 'key\n' > "${TMP}/fed_certs/tls.key"
cp "${TMP}/ca_public/root_ca.pem" "${TMP}/fed_peer_ca/pinned-peer.solution.example.pem"

cat > "${TMP}/bin/openssl" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  list) echo "providers"; exit 0 ;;
  pkcs12) for a in "$@"; do [ "$prev" = "-out" ] && : > "$a"; prev="$a"; done; exit 0 ;;
  x509)
    out=""; prev=""
    for a in "$@"; do [ "$prev" = "-out" ] && out="$a"; prev="$a"; done
    if [ -n "$out" ]; then printf -- '-----BEGIN CERTIFICATE-----\nleaf\n-----END CERTIFICATE-----\n' > "$out"; exit 0; fi
    case " $* " in
      *" extendedKeyUsage"*) echo "X509v3 Extended Key Usage:"; echo "    TLS Web Server Authentication, TLS Web Client Authentication" ;;
      *" -fingerprint "*) echo "sha256 Fingerprint=AA:BB:CC:DD" ;;
      *" -subject"*) echo "subject=CN=stub" ;;
      *" -issuer"*) echo "issuer=CN=stub-ca" ;;
      *" -enddate"*) echo "notAfter=Jan 1 00:00:00 2030 GMT" ;;
    esac
    exit 0 ;;
esac
exit 0
STUB

cat > "${TMP}/bin/keytool" <<'STUB'
#!/usr/bin/env bash
case " $* " in
  *" -importkeystore "*) for a in "$@"; do [ "$prev" = "-destkeystore" ] && : > "$a"; prev="$a"; done ;;
  *" -list "*) case " $* " in *" -v "*) echo "Certificate chain length: 3" ;; *) echo "stub truststore" ;; esac ;;
esac
exit 0
STUB

# Fetch succeeds except for the host named "unreachable", which covers the
# spawn-ordering path where a peer does not exist yet.
cat > "${TMP}/bin/curl" <<'STUB'
#!/usr/bin/env bash
out=""; url=""; prev=""
for a in "$@"; do
  [ "$prev" = "-o" ] && out="$a"
  case "$a" in https://*) url="$a" ;; esac
  prev="$a"
done
case "$url" in *unreachable*) exit 22 ;; esac
printf -- '-----BEGIN CERTIFICATE-----\nfetched\n-----END CERTIFICATE-----\n' > "$out"
STUB
chmod +x "${TMP}/bin"/*

PATH="${TMP}/bin:${PATH}" \
CERT_DIR_OVERRIDE=1 \
OWN_CA_DIR="${TMP}/ca_public" \
FED_TLS_DIR="${TMP}/fed_certs" \
PEER_CA_DIR="${TMP}/fed_peer_ca" \
TAKSERVER_KEYSTORE_PASS=x \
KEYSTORE_PASS=y \
TAK_SERVER_ADDRESS="tak.mmm.solution.example" \
TAK_FEDERATION_GROUP="default __ANON__" \
TAK_FEDERATION_PEERS="aaa.solution.example mmm.solution.example zzz.solution.example unreachable.solution.example" \
TAK_FEDERATION_FETCH_RETRIES=0 \
CERT_DIR="${TMP}/opt/tak/data/certs/files" \
FED_DIR="${TMP}/opt/tak/data/federation" \
  bash "${SCRIPT_UNDER_TEST}" \
  > "${TMP}/out.log" 2>&1 || { echo "FAIL: script exited non-zero"; cat "${TMP}/out.log"; exit 1; }

XML="${TMP}/opt/tak/data/federation/federation-extra.xml"
[ -s "${XML}" ] || { echo "FAIL: no federation-extra.xml written"; cat "${TMP}/out.log"; exit 1; }

# 1. Well-formed once wrapped in its parent element.
{ echo "<federation>"; cat "${XML}"; echo "</federation>"; } > "${TMP}/frag.xml"
xmllint --noout "${TMP}/frag.xml" || { echo "FAIL: generated XML is not well-formed"; exit 1; }

# 2. Child order: federation-outgoing before fileFilter before federateCA.
order="$(grep -oE '<(federation-outgoing|fileFilter|federateCA)' "${XML}" | sed 's/<//' | uniq | tr '\n' ' ')"
[ "${order}" = "federation-outgoing fileFilter federateCA " ] \
  || { echo "FAIL: wrong child order: '${order}'"; cat "${XML}"; exit 1; }

# 3. The pinned peer got a federateCA entry even though every fetch failed.
grep -q 'federateCA fingerprint="AA:BB:CC:DD"' "${XML}" \
  || { echo "FAIL: pinned peer CA produced no federateCA"; exit 1; }

# 4. Dial direction: we are mmm, so we dial zzz and never aaa or ourselves.
grep -q 'address="tak.zzz.solution.example"' "${XML}" \
  || { echo "FAIL: expected an outgoing connection to zzz"; cat "${XML}"; exit 1; }
grep -q 'address="tak.aaa.solution.example"' "${XML}" \
  && { echo "FAIL: must not dial aaa, it sorts before us"; cat "${XML}"; exit 1; }
grep -q 'tak.mmm.solution.example"' "${XML}" \
  && { echo "FAIL: must not federate with ourselves"; exit 1; }

# 5. aaa is trusted (federateCA) but not dialled - it sorts before us and dials in.
grep -q 'will wait for tak.aaa.solution.example' "${TMP}/out.log" \
  || { echo "FAIL: expected to wait for aaa to dial us"; cat "${TMP}/out.log"; exit 1; }

# 6. An unreachable peer warns and is skipped, and does not fail the pod.
grep -q 'could not fetch CA for unreachable.solution.example' "${TMP}/out.log" \
  || { echo "FAIL: expected a warning for the unreachable peer"; exit 1; }
grep -q 'unreachable.solution.example' "${XML}" \
  && { echo "FAIL: unreachable peer must not appear in the generated XML"; exit 1; }

# 7. A group list produces one inbound/outbound pair per group.
[ "$(grep -c '<inboundGroup>' "${XML}")" = "6" ] \
  || { echo "FAIL: expected 2 groups x 3 peers of inboundGroup"; cat "${XML}"; exit 1; }
grep -q '<inboundGroup>__ANON__</inboundGroup>' "${XML}" \
  || { echo "FAIL: second group missing"; exit 1; }

# 8. Asymmetric sharing: IN and OUT lists are applied independently.
PATH="${TMP}/bin:${PATH}" \
CERT_DIR_OVERRIDE=1 \
OWN_CA_DIR="${TMP}/ca_public" \
FED_TLS_DIR="${TMP}/fed_certs" \
PEER_CA_DIR="${TMP}/fed_peer_ca" \
TAKSERVER_KEYSTORE_PASS=x \
KEYSTORE_PASS=y \
TAK_SERVER_ADDRESS="tak.mmm.solution.example" \
TAK_FEDERATION_GROUP_IN="partner" \
TAK_FEDERATION_GROUP_OUT="default recon" \
TAK_FEDERATION_PEERS="aaa.solution.example mmm.solution.example zzz.solution.example" \
TAK_FEDERATION_FETCH_RETRIES=0 \
CERT_DIR="${TMP}/opt/tak/data/certs/files" \
FED_DIR="${TMP}/opt/tak/data/federation2" \
  bash "${SCRIPT_UNDER_TEST}" \
  > "${TMP}/out2.log" 2>&1 || { echo "FAIL: asymmetric run exited non-zero"; cat "${TMP}/out2.log"; exit 1; }

XML2="${TMP}/opt/tak/data/federation2/federation-extra.xml"
# 3 trusted peer CAs x 1 inbound group, x 2 outbound groups.
[ "$(grep -c '<inboundGroup>partner</inboundGroup>' "${XML2}")" = "3" ] \
  || { echo "FAIL: expected 3 inboundGroup partner"; cat "${XML2}"; exit 1; }
[ "$(grep -c '<outboundGroup>' "${XML2}")" = "6" ] \
  || { echo "FAIL: expected 6 outboundGroup"; cat "${XML2}"; exit 1; }
grep -q '<outboundGroup>partner</outboundGroup>' "${XML2}" \
  && { echo "FAIL: inbound-only group leaked into outbound"; exit 1; }
grep -q '<inboundGroup>recon</inboundGroup>' "${XML2}" \
  && { echo "FAIL: outbound-only group leaked into inbound"; exit 1; }
{ echo "<federation>"; cat "${XML2}"; echo "</federation>"; } > "${TMP}/frag2.xml"
xmllint --noout "${TMP}/frag2.xml" || { echo "FAIL: asymmetric XML not well-formed"; exit 1; }

echo "PASS: order, pinned peer, dial direction, group list, asymmetric in/out, self-exclusion, unreachable-peer tolerance"
