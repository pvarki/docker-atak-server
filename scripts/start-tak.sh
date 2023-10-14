#!/usr/bin/env -S /bin/bash
set -e

TR=/opt/tak
CONFIG=${TR}/data/CoreConfig.xml

SETUP_CERTS_USING_MANIFEST="${SETUP_CERTS_USING_MANIFEST:-no}"
TAK_ADMIN_CERT_FILENAME="${TAK_ADMIN_CERT_FILENAME:-tak-superjyra666.pem}"

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
    if [[ "${SETUP_CERTS_USING_MANIFEST}" == "yes" ]];then
      # If the cert file is not found in the files path, assume that the admin needs to be initialized
      # TODO check that if the user has already been added
      ADMIN_CERT_NAME="$(echo $TAK_ADMIN_CERT_FILENAME |sed 's/.pem//g')" /opt/scripts/enable_admin.sh &
    fi
    echo "Starting TAK Messaging"
    java -jar -Xmx${MESSAGING_MAX_HEAP}m -Dspring.profiles.active=messaging takserver.war
elif [ $1 = "api" ]; then
    echo "Starting TAK API"
    java -jar -Xmx${API_MAX_HEAP}m -Dspring.profiles.active=api -Dkeystore.pkcs12.legacy takserver.war
elif [ $1 = "pm" ]; then
    echo "Starting TAK Plugin Manager"
    java -jar -Xmx${PLUGIN_MANAGER_MAX_HEAP}m takserver-pm.jar
elif [ $1 = "users_loop" ]; then
    echo "Starting users loop purkka"
    while true
    do
      # TODO MAYBE IF NOT THEN MAYBE YES
      # Add logic for adding/removing users in case we cannot add the users through Tak REST Api
      # We need to be able to add users like the script "enable_admin.sh"
      #
      sleep 1
    done

else
  echo "Please provide right TAK component: messaging, api or pm"
fi
