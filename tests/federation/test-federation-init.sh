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
    if [ -n "$out" ]; then
      if [ -n "${STUB_BAD_CERT:-}" ]; then echo "Unable to load certificate" >&2; exit 1; fi
      printf -- '-----BEGIN CERTIFICATE-----\nleaf\n-----END CERTIFICATE-----\n' > "$out"; exit 0
    fi
    case " $* " in
      *" extendedKeyUsage"*) echo "X509v3 Extended Key Usage:"; echo "    ${STUB_EKU:-TLS Web Server Authentication, TLS Web Client Authentication}" ;;
      *" -fingerprint "*) echo "sha256 Fingerprint=${STUB_FP:-AA:BB:CC:DD}" ;;
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

# ---------------------------------------------------------------------------
# Security fixes: findings 1 and 7
# ---------------------------------------------------------------------------
run_fed() {  # run_fed <feddir> [extra env assignments...]
  local feddir="$1"; shift
  env PATH="${TMP}/bin:${PATH}" \
      OWN_CA_DIR="${TMP}/ca_public" \
      FED_TLS_DIR="${TMP}/fed_certs" \
      PEER_CA_DIR="${TMP}/fed_peer_ca" \
      TAKSERVER_KEYSTORE_PASS=x KEYSTORE_PASS=y \
      TAK_SERVER_ADDRESS="tak.mmm.solution.example" \
      TAK_FEDERATION_PEERS="zzz.solution.example pinned-peer.solution.example" \
      TAK_FEDERATION_FETCH_RETRIES=0 \
      CERT_DIR="${TMP}/opt/tak/data/certs/files" \
      FED_DIR="${feddir}" \
      "$@" bash "${SCRIPT_UNDER_TEST}"
}

# 9. Finding 1b: a changed peer CA fingerprint is REFUSED, not silently re-trusted.
D9="${TMP}/opt/tak/data/fed9"
run_fed "$D9" > "${TMP}/r9a.log" 2>&1 || { echo "FAIL: first run failed"; cat "${TMP}/r9a.log"; exit 1; }
grep -q 'recorded first-seen CA for zzz.solution.example' "${TMP}/r9a.log" \
  || { echo "FAIL: first-seen fingerprint not recorded"; cat "${TMP}/r9a.log"; exit 1; }
[ -f "$D9/known-peer-cas/zzz.solution.example.sha256" ] \
  || { echo "FAIL: no persisted fingerprint file"; exit 1; }
grep -q '<federateCA fingerprint="AA:BB:CC:DD"' "$D9/federation-extra.xml" \
  || { echo "FAIL: peer not federated on first run"; exit 1; }

run_fed "$D9" STUB_FP="EE:FF:00:11" > "${TMP}/r9b.log" 2>&1 \
  || { echo "FAIL: rotated-CA run should still exit 0"; cat "${TMP}/r9b.log"; exit 1; }
grep -q 'REFUSING zzz.solution.example' "${TMP}/r9b.log" \
  || { echo "FAIL: changed fingerprint was NOT refused"; cat "${TMP}/r9b.log"; exit 1; }
# The refused peer must drop out of the config entirely. Both peers federate on the
# first run; after the rotation only the pinned one may remain. (Asserting on the
# fingerprint itself would be wrong here - the stub gives every cert the same one.)
[ "$(grep -c '<federateCA' "$D9/federation-extra.xml")" = "1" ] \
  || { echo "FAIL: expected exactly 1 federateCA after refusal"; cat "$D9/federation-extra.xml"; exit 1; }
grep -q 'federation-outgoing displayName="zzz.solution.example"' "$D9/federation-extra.xml" \
  && { echo "FAIL: refused peer still has an outgoing connection"; exit 1; }

# 10. Finding 1a: a configmap-pinned CA is authoritative and is never fetched over.
grep -q 'pinned by configmap; not fetching' "${TMP}/r9a.log" \
  || { echo "FAIL: pinned peer was fetched over"; cat "${TMP}/r9a.log"; exit 1; }
# ...and rotating the *fetched* fingerprint must not disturb the pinned peer.
grep -q 'REFUSING pinned-peer' "${TMP}/r9b.log" \
  && { echo "FAIL: pinned peer wrongly subjected to TOFU check"; exit 1; }

# 11. Finding 7: a broken identity degrades to federation-off, exit 0, no fragment,
#     and a usable keystore is still left behind so TAK can start.
D11="${TMP}/opt/tak/data/fed11"
printf 'takserver-jks\n' > "${TMP}/opt/tak/data/certs/files/takserver.jks"
rm -f "${TMP}/opt/tak/data/certs/files/fed-keystore.jks"
run_fed "$D11" STUB_EKU="TLS Web Server Authentication" > "${TMP}/r11.log" 2>&1 \
  || { echo "FAIL: degraded run must exit 0 so TAK still starts"; cat "${TMP}/r11.log"; exit 1; }
grep -q 'Federation DISABLED' "${TMP}/r11.log" \
  || { echo "FAIL: no degrade message"; cat "${TMP}/r11.log"; exit 1; }
[ ! -f "$D11/federation-extra.xml" ] \
  || { echo "FAIL: degraded run still wrote a federation fragment"; exit 1; }
[ -s "${TMP}/opt/tak/data/certs/files/fed-keystore.jks" ] \
  || { echo "FAIL: degraded run left no keystore - TAK would fail to start"; exit 1; }

# 12. Finding 7, the case only the live server caught: an UNREADABLE cert made
#     openssl fail, and `set -e` aborted before fatal() ever ran - so TAK died.
#     A wrong EKU was not enough to reproduce it; this is.
D12="${TMP}/opt/tak/data/fed12"
rm -f "${TMP}/opt/tak/data/certs/files/fed-keystore.jks"
run_fed "$D12" STUB_BAD_CERT=1 > "${TMP}/r12.log" 2>&1 \
  || { echo "FAIL: unreadable cert must degrade, not abort"; cat "${TMP}/r12.log"; exit 1; }
grep -q 'not a readable certificate' "${TMP}/r12.log" \
  || { echo "FAIL: no diagnostic for unreadable cert"; cat "${TMP}/r12.log"; exit 1; }
grep -q 'Federation DISABLED' "${TMP}/r12.log" \
  || { echo "FAIL: did not degrade"; cat "${TMP}/r12.log"; exit 1; }
[ -s "${TMP}/opt/tak/data/certs/files/fed-keystore.jks" ] \
  || { echo "FAIL: no keystore left behind - TAK would fail to start"; exit 1; }

echo "PASS: order, pinned peer, dial direction, group list, asymmetric in/out, self-exclusion, unreachable-peer tolerance, CA-rotation refused, pin honoured, degrade-not-die, unreadable-cert-degrades"
