#!/usr/bin/env -S /bin/bash
set -e

TR=/opt/tak
CONFIG=${TR}/data/CoreConfig.xml

RM_API_MANIFEST_FILE="${RM_API_MANIFEST_FILE:=/opt/tak/data/certs/rm_api_manifest.json}"

# (re-)Create config
echo "(Re-)Creating config"
cat /opt/templates/CoreConfig.tpl | gomplate >${CONFIG}
# make sure it's in tak root too
cp ${CONFIG} ${TR}

# Symlink the certs coming from Volumes
if [[ ! -L "${TR}/certs"  ]];then
  mv ${TR}/certs ${TR}/certs.orig
  ln -s "${TR}/data/certs/" "${TR}/certs"
fi

# Symlink the log directory coming from Volumes
if [[ ! -L "${TR}/logs"  ]];then
  mv ${TR}/logs ${TR}/logs.orig
  ln -s "${TR}/data/logs/" "${TR}/logs"
fi

# Change to workdir
cd ${TR}

# This will set bunch of variables
. ./setenv.sh

# Start the right process
if [ $1 = "messaging" ]; then
    
    if [[ -f "${RM_API_MANIFEST_FILE}" ]];then
      echo "Manifest found in ${RM_API_MANIFEST_FILE}, attempting to initialize admin using manifest"
      # If the cert file is not found in the files path, assume that the admin needs to be initialized
      if [ ! -f "/opt/tak/certs/files/${TAK_ADMIN_CERT_FILENAME}" ];then
        TAK_ADMIN_CERT_FILENAME=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .tak_admin_cert_filename)
        cp "/opt/tak/certs/${TAK_ADMIN_CERT_FILENAME}" "/opt/tak/certs/files/${TAK_ADMIN_CERT_FILENAME}"
        ADMIN_CERT_NAME="$(echo $TAK_ADMIN_CERT_FILENAME |sed 's/.pem//g')" /opt/scripts/enable_admin.sh &
      else
        echo "Assuming that the admin initialization has already been done as /opt/tak/certs/files/${TAK_ADMIN_CERT_FILENAME} is found"
        echo "Skipping admin init..."
      fi
      
    fi
    echo "Starting TAK Messaging"
    java -jar -Xmx${MESSAGING_MAX_HEAP}m -Dspring.profiles.active=messaging takserver.war
elif [ $1 = "api" ]; then
    echo "Starting TAK API"
    java -jar -Xmx${API_MAX_HEAP}m -Dspring.profiles.active=api -Dkeystore.pkcs12.legacy takserver.war
elif [ $1 = "pm" ]; then
    echo "Starting TAK Plugin Manager"
    java -jar -Xmx${PLUGIN_MANAGER_MAX_HEAP}m takserver-pm.jar
else
  echo "Please provide right TAK component: messaging, api or pm"
fi
