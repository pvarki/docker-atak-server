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

FED_TLS_DIR="${FED_TLS_DIR:-/fed_certs}"     # cert-manager secret tak-federation-tls
PEER_CA_DIR="${PEER_CA_DIR:-/fed_peer_ca}"   # ConfigMap of committed peer CA PEMs
OWN_CA_DIR="${OWN_CA_DIR:-/ca_public}"       # written by the certs-handler init container

# Names match firstrun_rm.sh. tak.externalsecret.yaml keeps these equal to the
# TAKSERVER_CERT_PASS / CA_PASS that CoreConfig.tpl uses to open the same stores.
TAKSERVER_KEYSTORE_PASS="${TAKSERVER_KEYSTORE_PASS:?TAKSERVER_KEYSTORE_PASS is required}"
KEYSTORE_PASS="${KEYSTORE_PASS:?KEYSTORE_PASS is required}"

FED_ALIAS="${TAK_SERVER_ADDRESS:-takserver}"
FED_STRICT="${FED_STRICT:-true}"
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
  log "FATAL - $*"
  if [[ "${FED_STRICT}" == "true" ]]; then exit 1; fi
  log "FED_STRICT=false, continuing with a federation identity that will not work"
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
  log "WARNING - federation will NOT work until a tak-federation Certificate is deployed"
  cp -v "${CERT_DIR}/takserver.jks" "${CERT_DIR}/fed-keystore.jks"
else
  # `openssl x509 -in` emits only the first certificate, so this strips any chain
  # cert-manager already appended and -certfile below cannot duplicate it.
  openssl x509 -in "${FED_TLS_DIR}/tls.crt" -out "${WORK}/leaf.pem"

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
    fatal "federation identity has no clientAuth EKU; outgoing federation cannot authenticate" ;;
  esac
  case "${EKU}" in *"TLS Web Server Authentication"*) ;; *)
    fatal "federation identity has no serverAuth EKU; inbound ${FED_PORT} cannot serve" ;;
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
    fatal "fed-keystore.jks has no issuer in its chain; the peer cannot identify our CA"
  fi
fi

# ---------------------------------------------------------------------------
# 2. Collect peer CAs
#
# Two sources, both optional and additive:
#   - PEMs mounted from a ConfigMap  (manual / pinned peers)
#   - fetched from TAK_FEDERATION_PEERS over HTTPS  (spawned fleets)
# The fetch is NOT trust-on-first-use: /ca/public is served by Traefik on 443
# behind a publicly trusted Let's Encrypt certificate, so curl verifies it.
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/peers"
shopt -s nullglob
for pem in "${PEER_CA_DIR}"/*.pem; do
  cp "${pem}" "${WORK}/peers/$(basename "${pem}")"
  log "peer CA from configmap: $(basename "${pem}")"
done
shopt -u nullglob

for peer in ${FED_PEERS}; do
  if [[ "${peer}" == "${OWN_HOST}" ]]; then
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
  import_ca "peer_${peer}" "${pem}"
  fp="$(ca_fingerprint "${pem}")"
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
