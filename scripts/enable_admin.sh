#!/usr/bin/env -S /bin/bash
set -e
echo "enable_admin: Making sure ${ADMIN_CERT_NAME} user is in place"
exec /bin/bash /opt/scripts/user-manager.sh certmod -A "/opt/tak/data/certs/files/${ADMIN_CERT_NAME}.pem"
