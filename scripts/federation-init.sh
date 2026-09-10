#!/usr/bin/env -S /bin/bash
#
# Build the TAK federation identity keystore, the federation truststore, and the
# generated <federation> tail that CoreConfig.tpl splices in.
#
# ORDERING: run this AFTER firstrun_rm.sh, which seeds fed-truststore.jks with this
# deployment's own CAs. This script then adds the peer CAs on top and writes the
# <federation> fragment that CoreConfig.tpl splices in via TAK_FEDERATION_EXTRA_FILE.
#
# IDEMPOTENCY: runs on every pod start. Both stores and the XML are rebuilt from
# scratch, so stale peers cannot accumulate and no `keytool -delete` can trip set -e.

set -euo pipefail

# Overridable so the script can be exercised outside a TAK container (see the test that
# ships with it); in the image these are the real paths and nothing needs to set them.
CERT_DIR="${CERT_DIR:-/opt/tak/data/certs/files}"
FED_DIR="${FED_DIR:-/opt/tak/data/federation}"
FED_XML="${FED_DIR}/federation-extra.xml"
# First-seen peer CA fingerprints. On the tak-data volume so it survives restarts:
# without it the "pin" would be re-derived from the network on every boot.
KNOWN_DIR="${FED_DIR}/known-peer-cas"

FED_TLS_DIR="${FED_TLS_DIR:-/fed_certs}"     # cert-manager secret tak-federation-tls
PEER_CA_DIR="${PEER_CA_DIR:-/fed_peer_ca}"   # ConfigMap of committed peer CA PEMs
OWN_CA_DIR="${OWN_CA_DIR:-/ca_public}"       # written by the certs-handler init container

# Names match firstrun_rm.sh. tak.externalsecret.yaml keeps these equal to the
# TAKSERVER_CERT_PASS / CA_PASS that CoreConfig.tpl uses to open the same stores.
TAKSERVER_KEYSTORE_PASS="${TAKSERVER_KEYSTORE_PASS:?TAKSERVER_KEYSTORE_PASS is required}"
KEYSTORE_PASS="${KEYSTORE_PASS:?KEYSTORE_PASS is required}"

FED_ALIAS="${TAK_SERVER_ADDRESS:-takserver}"
# Default false: federation is an OPTIONAL feature and must not be able to take
# port 8089 down for every fielded ATAK client. A broken federation identity now
# degrades to "federation off" and TAK starts normally. Set true in CI, where a
# hard failure is exactly what you want.
FED_STRICT="${FED_STRICT:-false}"
FED_DEGRADED=0
# Space-separated: <federateCA> takes unbounded inboundGroup/outboundGroup children,
# so several groups can be mapped at once (e.g. "default __ANON__").
FED_GROUP="${TAK_FEDERATION_GROUP:-default __ANON__}"
# Asymmetric sharing: what we ACCEPT from a peer and what we SEND need not match.
# Both default to TAK_FEDERATION_GROUP, so the symmetric case stays a single var.
#   TAK_FEDERATION_GROUP_IN   - local groups incoming federated traffic is filed under
#   TAK_FEDERATION_GROUP_OUT  - local groups whose traffic is shared with the peer
# e.g. GROUP_OUT="recon" GROUP_IN="partner" exports only recon and quarantines
# everything the peer sends into a group your own users are not in.
FED_GROUP_IN="${TAK_FEDERATION_GROUP_IN:-${FED_GROUP}}"
FED_GROUP_OUT="${TAK_FEDERATION_GROUP_OUT:-${FED_GROUP}}"
FED_PEERS="${TAK_FEDERATION_PEERS:-}"
FED_PORT="${TAK_FEDERATION_PORT:-9001}"
FED_FETCH_RETRIES="${TAK_FEDERATION_FETCH_RETRIES:-5}"

# TAK_SERVER_ADDRESS is tak.<host>; peers are listed as bare <host>.
OWN_HOST="${FED_ALIAS#tak.}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${CERT_DIR}" "${FED_DIR}"

log() { echo "federation-init: $*"; }
fatal() {
  log "ERROR - $*"
  if [[ "${FED_STRICT}" == "true" ]]; then
    log "FED_STRICT=true, failing the container"
    exit 1
  fi
  # Do NOT carry on building federation config from a broken identity: that used to
  # produce a half-configured server. Mark it and bail out cleanly below instead.
  log "Federation DISABLED for this run; TAK itself will start normally."
  FED_DEGRADED=1
}

# ---------------------------------------------------------------------------
# 1. Federation identity keystore
#
# Exactly ONE key entry: CoreConfig pins keymanager="SunX509", whose alias choice
# is by key algorithm and issuer, so a second entry makes the choice ambiguous.
#
# The chain is mandatory, not cosmetic: TAK identifies a peer by its certArray[1]
# (FederationServer.java). A leaf-only keystore throws ArrayIndexOutOfBounds inside
# the interceptor, which surfaces only as a generic Status.INTERNAL.
# ---------------------------------------------------------------------------
if [[ ! -s "${FED_TLS_DIR}/tls.crt" || ! -s "${FED_TLS_DIR}/tls.key" ]]; then
  # TAK_FED_KEYSTORE_FILE is set in base, so this path must always exist or every
  # JVM fails to start. Falling back to takserver.jks keeps the pod behaving exactly
  # as it did before federation existed: it comes up, and federation cannot
  # authenticate outbound because the Let's Encrypt cert has no clientAuth EKU.
  log "WARNING - no federation identity at ${FED_TLS_DIR}; falling back to takserver.jks"
  log "WARNING - federation will NOT work: takserver.jks holds the web certificate, and a"
  log "WARNING - Let's Encrypt cert has no clientAuth EKU, so no peer can ever accept it."
  if [[ "${TAK_FEDERATION_ENABLED:-false}" == "true" ]]; then
    # The operator asked for an identity and did not get one, so the mint is broken
    # rather than merely skipped. Say so, because the fallback below looks identical.
    log "WARNING - TAK_FEDERATION_ENABLED=true but no identity arrived: the mint did not"
    log "WARNING - run or it failed. Check the takfedinit cfssl step and the cfssl logs."
  else
    log "WARNING - To fix on compose: set TAK_FEDERATION_ENABLED=true (or configure"
    log "WARNING - TAK_FEDERATION_PEERS) and restart. On Kubernetes: deploy the"
    log "WARNING - tak-federation Certificate so ${FED_TLS_DIR} is populated."
  fi
  cp -v "${CERT_DIR}/takserver.jks" "${CERT_DIR}/fed-keystore.jks"
else
  # Everything that can fail on a bad identity lives in this function, and it is
  # called with `if ! ...` so `set -e` is suspended for the whole call. Without
  # that, a corrupt tls.crt aborts the script outright and never reaches fatal(),
  # which is exactly how a broken federation cert used to take TAK down.
  build_fed_identity() {
  # `openssl x509 -in` emits only the first certificate, so this strips any chain
  # cert-manager already appended and -certfile below cannot duplicate it.
  openssl x509 -in "${FED_TLS_DIR}/tls.crt" -out "${WORK}/leaf.pem" 2>/dev/null \
    || { log "ERROR - ${FED_TLS_DIR}/tls.crt is not a readable certificate"; return 1; }

  EKU="$(openssl x509 -in "${WORK}/leaf.pem" -noout -ext extendedKeyUsage 2>/dev/null || true)"
  log "identity subject : $(openssl x509 -in "${WORK}/leaf.pem" -noout -subject)"
  log "identity issuer  : $(openssl x509 -in "${WORK}/leaf.pem" -noout -issuer)"
  log "identity notAfter: $(openssl x509 -in "${WORK}/leaf.pem" -noout -enddate)"
  log "identity EKU     : ${EKU//$'\n'/ }"

  # Checked here because the peer, not us, is what rejects a clientAuth-less cert:
  # SunX509 picks an alias by key type and issuer and never looks at the EKU, so
  # we would present it happily and see only a TLS alert. The legible error lands
  # in the PEER's log.
  case "${EKU}" in *"TLS Web Client Authentication"*) ;; *)
    log "ERROR - federation identity has no clientAuth EKU; outgoing federation cannot authenticate"
    return 1 ;;
  esac
  case "${EKU}" in *"TLS Web Server Authentication"*) ;; *)
    log "ERROR - federation identity has no serverAuth EKU; inbound ${FED_PORT} cannot serve"
    return 1 ;;
  esac

  # Mirror firstrun_rm.sh's legacy-provider detection so both keystores are built
  # by the same PKCS#12 code path.
  LEGACY_PROVIDER=""
  if ! openssl list -providers 2>&1 | grep -q "\(invalid command\|unknown option\)"; then
    LEGACY_PROVIDER="-legacy"
  fi

  cat "${OWN_CA_DIR}/intermediate_ca.pem" "${OWN_CA_DIR}/root_ca.pem" > "${WORK}/chain.pem"

  openssl pkcs12 ${LEGACY_PROVIDER} -export \
    -out "${WORK}/fed.p12" \
    -inkey "${FED_TLS_DIR}/tls.key" \
    -in "${WORK}/leaf.pem" \
    -certfile "${WORK}/chain.pem" \
    -name "${FED_ALIAS}" \
    -passout "pass:${TAKSERVER_KEYSTORE_PASS}"

  rm -f "${CERT_DIR}/fed-keystore.jks"
  keytool -importkeystore -noprompt \
    -srcstoretype PKCS12 \
    -srckeystore "${WORK}/fed.p12" -srcstorepass "${TAKSERVER_KEYSTORE_PASS}" \
    -destkeystore "${CERT_DIR}/fed-keystore.jks" -deststoretype JKS \
    -deststorepass "${TAKSERVER_KEYSTORE_PASS}" -destkeypass "${TAKSERVER_KEYSTORE_PASS}" \
    -alias "${FED_ALIAS}"

  CHAIN_LEN="$(keytool -list -v -keystore "${CERT_DIR}/fed-keystore.jks" \
    -storepass "${TAKSERVER_KEYSTORE_PASS}" | sed -n 's/.*Certificate chain length: //p' | head -1)"
  log "built fed-keystore.jks alias=${FED_ALIAS} chain length=${CHAIN_LEN:-0}"
  if [[ "${CHAIN_LEN:-0}" -lt 2 ]]; then
    log "ERROR - fed-keystore.jks has no issuer in its chain; the peer cannot identify our CA"
    return 1
  fi
  return 0
  }

  if ! build_fed_identity; then
    fatal "could not build a usable federation identity from ${FED_TLS_DIR}"
  fi
fi

# ---------------------------------------------------------------------------
# 1b. Degrade cleanly if the identity is unusable
#
# CoreConfig points TAK_FED_KEYSTORE_FILE at fed-keystore.jks unconditionally, so
# that file must exist or every JVM fails to start. Leave a working keystore, drop
# any stale fragment, and exit 0 so the rest of TAK comes up without federation.
# ---------------------------------------------------------------------------
if [[ "${FED_DEGRADED}" == "1" ]]; then
  if [[ ! -s "${CERT_DIR}/fed-keystore.jks" ]]; then
    cp -v "${CERT_DIR}/takserver.jks" "${CERT_DIR}/fed-keystore.jks"
  fi
  rm -f "${FED_XML}"
  log "done (federation disabled, TAK unaffected)"
  exit 0
fi

# ---------------------------------------------------------------------------
# 2. Collect peer CAs
#
# Two sources, in strict precedence order:
#   1. PEMs mounted from a ConfigMap  -- AUTHORITATIVE, never fetched over
#   2. fetched from TAK_FEDERATION_PEERS over HTTPS  (spawned fleets)
#
# What the fetch actually proves is only "somebody who can pass ACME for that
# hostname", so it is trust-on-first-use, not a pin. curl does verify TLS (there
# is deliberately no -k and no -L, so a redirect-to-http downgrade is blocked),
# but DNS control over a peer name is enough to serve us a hostile CA. That is
# why the first-seen fingerprint is remembered in KNOWN_DIR below and a change
# is refused: mount the CA from a ConfigMap to pin it from the very first run.
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/peers" "${KNOWN_DIR}"
PINNED_PEERS=""
shopt -s nullglob
for pem in "${PEER_CA_DIR}"/*.pem; do
  cp "${pem}" "${WORK}/peers/$(basename "${pem}")"
  PINNED_PEERS="${PINNED_PEERS} $(basename "${pem}" .pem)"
  log "peer CA from configmap (authoritative): $(basename "${pem}")"
done
shopt -u nullglob

for peer in ${FED_PEERS}; do
  if [[ "${peer}" == "${OWN_HOST}" ]]; then
    continue
  fi
  # A ConfigMap-mounted CA is the operator's explicit pin. Fetching over it would
  # let whoever controls the peer's DNS silently replace it -- and the rm -f below
  # would delete it outright when the fetch failed.
  if [[ " ${PINNED_PEERS} " == *" ${peer} "* ]]; then
    log "peer CA for ${peer} is pinned by configmap; not fetching"
    continue
  fi
  if curl -fsS --retry "${FED_FETCH_RETRIES}" --retry-delay 5 --retry-connrefused --max-time 30 \
       "https://${peer}/ca/public/intermediate_ca.pem" -o "${WORK}/peers/${peer}.pem"; then
    log "peer CA fetched: ${peer}"
  else
    # Never fail the pod for an unreachable peer: when a fleet is spawned in
    # parallel some peers do not exist yet. A missing peer means no <federateCA>
    # for it, so the link is simply absent rather than half-configured. Re-run
    # (kubectl rollout restart) once the whole fleet is up.
    rm -f "${WORK}/peers/${peer}.pem"
    log "WARNING - could not fetch CA for ${peer}; it will not be federated this run"
  fi
done

# ---------------------------------------------------------------------------
# 3. Federation truststore
#
# Rebuilt from scratch so it is a pure function of the inputs above.
# truststore-root.jks is deliberately NOT touched: it authenticates ATAK clients
# on 8089, and a peer unit's CA in there would let that unit mint users here.
# firstrun_rm.sh leaves both files as our own CAs, so adding peers to this one
# alone is what splits them.
# ---------------------------------------------------------------------------
import_ca() { # import_ca <alias> <pem>
  local alias="$1" pem="$2"
  keytool -noprompt -importcert -trustcacerts \
    -alias "${alias}" -file "${pem}" \
    -keystore "${CERT_DIR}/fed-truststore.jks" -storepass "${KEYSTORE_PASS}"
}

ca_fingerprint() { openssl x509 -in "$1" -noout -fingerprint -sha256 | cut -d= -f2; }

rm -f "${CERT_DIR}/fed-truststore.jks"
import_ca RM_Root "${OWN_CA_DIR}/root_ca.pem"
import_ca RM_Intermediate "${OWN_CA_DIR}/intermediate_ca.pem"

OUTGOING=""
FEDERATE_CA=""
PEER_COUNT=0

shopt -s nullglob
for pem in "${WORK}/peers"/*.pem; do
  grep -q "BEGIN CERTIFICATE" "${pem}" || { log "WARNING - ${pem} is not a certificate"; continue; }
  peer="$(basename "${pem}" .pem)"
  fp="$(ca_fingerprint "${pem}")"

  # Fingerprint must be checked BEFORE the CA is imported, or a rotated hostile CA
  # is already a trust anchor by the time we notice. Pinned CAs skip this: the
  # ConfigMap is the pin, and an operator editing it should win.
  if [[ " ${PINNED_PEERS} " != *" ${peer} "* ]]; then
    known="${KNOWN_DIR}/${peer}.sha256"
    if [[ -f "${known}" && "$(cat "${known}")" != "${fp}" ]]; then
      log "REFUSING ${peer}: CA fingerprint changed since first trust"
      log "  expected $(cat "${known}")"
      log "  got      ${fp}"
      log "  Someone who controls that hostname can serve any CA. If this rotation"
      log "  is legitimate: rm ${known} and restart. Not federating with it now."
      continue
    fi
    if [[ ! -f "${known}" ]]; then
      echo "${fp}" > "${known}"
      log "recorded first-seen CA for ${peer} (pin it via configmap to avoid TOFU)"
    fi
  fi

  import_ca "peer_${peer}" "${pem}"
  PEER_COUNT=$((PEER_COUNT + 1))
  log "trust peer_${peer}  sha256=${fp}  $(openssl x509 -in "${pem}" -noout -subject)"

  groups=""
  for g in ${FED_GROUP_IN}; do
    groups="${groups}            <inboundGroup>${g}</inboundGroup>
"
  done
  for g in ${FED_GROUP_OUT}; do
    groups="${groups}            <outboundGroup>${g}</outboundGroup>
"
  done
  FEDERATE_CA="${FEDERATE_CA}        <federateCA fingerprint=\"${fp}\" maxHops=\"-1\" allowTokenAuth=\"false\">
${groups}        </federateCA>
"
  # Exactly one side of each pair must dial: FederationServer raises
  # DuplicateFederateException and the link flaps if both do. Comparing hostnames
  # gives a stable answer on both sides with no coordination.
  if [[ "${peer}" > "${OWN_HOST}" ]]; then
    OUTGOING="${OUTGOING}        <federation-outgoing displayName=\"${peer}\" address=\"tak.${peer}\" port=\"${FED_PORT}\" protocolVersion=\"2\" enabled=\"true\" tls=\"true\" reconnectInterval=\"30\" unlimitedRetries=\"true\" maxFrameSize=\"268435456\"/>
"
    log "will dial tak.${peer}:${FED_PORT} (we sort first)"
  else
    log "will wait for tak.${peer} to dial us (they sort first)"
  fi
done
shopt -u nullglob

keytool -list -keystore "${CERT_DIR}/fed-truststore.jks" -storepass "${KEYSTORE_PASS}" \
  | sed 's/^/federation-init: /'

# ---------------------------------------------------------------------------
# 4. The generated <federation> tail
#
# Child order is fixed by CoreConfig.xsd: federation-outgoing*, fileFilter, federateCA*.
# No peers -> no file -> CoreConfig.tpl falls back to the stock <fileFilter> block.
# ---------------------------------------------------------------------------
if [[ "${PEER_COUNT}" -eq 0 ]]; then
  rm -f "${FED_XML}"
  log "no peers configured; CoreConfig will use the stock federation block"
else
  printf '%s        <fileFilter>\n            <fileExtension>pref</fileExtension>\n        </fileFilter>\n%s' \
    "${OUTGOING}" "${FEDERATE_CA}" > "${FED_XML}"
  log "wrote ${FED_XML} for ${PEER_COUNT} peer(s), in=${FED_GROUP_IN} out=${FED_GROUP_OUT}"
  case " ${FED_GROUP_OUT} " in *" default "*) ;; *)
    # Deploy App enrols users with a bare `UserManager certmod` (enable_user.sh, no -g),
    # which puts them in __ANON__ - verified in UserAuthenticationFile.xml on a live
    # deployment. x509addAnonymous="false" only stops the *automatic* x509 add; the
    # explicit groupList still applies. So __ANON__ is the group that actually has
    # members here, and anything else needs its membership arranged first.
    # Measured on a live deployment: a cert-authenticated client's runtime subscription
    # lands in "default", even though UserAuthenticationFile.xml lists __ANON__ for the
    # same user. Federation only forwards where the client's groups and the federate's
    # groups intersect, so leaving "default" out silently forwards nothing.
    log "NOTE - outbound group list ${FED_GROUP_OUT} does not include \"default\"."
    log "NOTE - Connected clients are usually in \"default\" at runtime; without it,"
    log "NOTE - federation connects cleanly and sends no CoT at all." ;;
  esac
fi

log "done"
