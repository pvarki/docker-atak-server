#!/usr/bin/env -S /bin/bash
set -e
exec /bin/bash /opt/scripts/user-manager.sh certmod "/opt/tak/data/certs/files/${USER_CERT_NAME}.pem"
