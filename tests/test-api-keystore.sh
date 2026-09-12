#!/usr/bin/env bash
# Run in a disposable TAK image: exercise startup while replacing only the JVM.
set -euo pipefail
scripts="$(cd "$(dirname "$0")/../scripts" && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT
cat > "${workdir}/java" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${SERVER_SSL_KEY_STORE:-unset}"
SH
chmod +x "${workdir}/java"
export PATH="${workdir}:${PATH}"
unset TAK_HTTPS_KEYSTORE_FILENAME SERVER_SSL_KEY_STORE
[[ "$(bash "${scripts}/run-tak.sh" api | tail -1)" == /opt/tak/data/certs/files/takserver-https.jks ]]
[[ "$(TAK_HTTPS_KEYSTORE_FILENAME=/custom/https.jks bash "${scripts}/run-tak.sh" api | tail -1)" == /custom/https.jks ]]
[[ "$(bash "${scripts}/run-tak.sh" messaging | tail -1)" == unset ]]
echo 'PASS: primary HTTPS connector uses the separate default or explicit override; CoT startup is unaffected'
