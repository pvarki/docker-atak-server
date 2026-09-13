#!/usr/bin/env -S /bin/bash
set -e
exec /bin/bash /opt/scripts/user-manager.sh certmod -g revoked "/opt/tak/data/certs/files/${USER_CERT_NAME}.pem"
