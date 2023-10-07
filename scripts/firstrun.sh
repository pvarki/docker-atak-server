#!/usr/bin/env -S /bin/bash
set -e

TR=/opt/tak
CR=${TR}/certs
CONFIG=${TR}/data/CoreConfig.xml

# Manifest as base64
RM_API_MANIFEST_B64="${RM_API_MANIFEST_B64:=}"
# Default manifest file
RM_API_MANIFEST_FILE="${RM_API_MANIFEST_FILE:=/opt/tak/data/certs/rm_api_manifest.json}"
RM_USE_MANIFEST="no"

# Check the manifest
if [[ -f "${RM_API_MANIFEST_FILE}" ]];then
  echo "Manifest found in ${RM_API_MANIFEST_FILE}, attempting to initialize using rm."
  RM_USE_MANIFEST="yes"
# Check if the manifest os provided as base64 string
elif [[ "${RM_API_MANIFEST_B64}" != "" ]]; then
  echo "Manifest found in B64 decoded env var. Dumping it to ${RM_API_MANIFEST_FILE}"
  echo $RM_API_MANIFEST_B64 | base64 -d > "${RM_API_MANIFEST_FILE}"
  RM_USE_MANIFEST="yes"
fi

# err function
err_manifest_var_not (){
  echo "ERROR. Required variable not set! '$1' missing from manifest."
  exit 1
}

# Run init using manifest and exit 0 at end. 
if [[ "${RM_USE_MANIFEST}" == "yes" ]];then
  # Check that the manifest is some sort of json, if not then err and exit
  if ! cat "${RM_API_MANIFEST_FILE}" | jq  > /dev/null ; then
    echo "ERROR. Unable to pipe content of ${RM_API_MANIFEST_FILE} to jq."
    echo "#################"
    echo "#### OUTPUT ####"
    echo "#################"
    echo ""
    cat "${RM_API_MANIFEST_FILE}" | jq
    echo ""
    echo "####################"
    echo "# MANIFEST CONTENT #"
    echo "####################"
    echo ""
    cat "${RM_API_MANIFEST_FILE}"
    echo ""
    echo "#####################"

    exit 1
  fi
  
  # Get the values from manifest file
  RM_LOCAL_API_HOST=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .rasenmaher_host)
  RM_LOCAL_API_HEALTCHECK_URL=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .rasenmaher_healthcheck_url)
  TAK_SERVER_CERT_FILENAME=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .tak_server_cert_filename)
  TAK_SERVER_KEY_FILENAME=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .tak_server_key_filename)
  TAK_SERVER_KEY_PASSPHRASE=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .tak_server_key_passphrase)
  TAK_SERVER_HOSTNAME=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .tak_server_hostname)
  TAK_ADMIN_CERT_FILENAME=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .tak_admin_cert_filename)
  TAK_ADMIN_KEY_FILENAME=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .tak_admin_key_filename)
  TAK_ADMIN_KEY_PASSPHRASE=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .tak_admin_key_passphrase)
  RM_CERT_CHAIN_FILENAME=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .rm_cert_chain_filename)
  RM_STARTUP_CERTS_LOCAL_FOLDER=$(cat "${RM_API_MANIFEST_FILE}" | jq -r .rm_startup_certs_local_folder)

  # Output some stuff for debug
  echo "######"
  cat "${RM_API_MANIFEST_FILE}" | jq 
  echo "######"

  # Err if VALUE X not defined in manifest, check all values here for later use, possibly in other scripts... 
  if [[ "$RM_LOCAL_API_HOST" == "null" ]]; then err_manifest_var_not .rasenmaher_host ; fi
  if [[ "$RM_LOCAL_API_HEALTCHECK_URL" == "null" ]]; then err_manifest_var_not .rasenmaher_healthcheck_url ; fi
  if [[ "$TAK_SERVER_CERT_FILENAME" == "null" ]]; then err_manifest_var_not .tak_server_cert_filename ; fi
  if [[ "$TAK_SERVER_KEY_FILENAME" == "null" ]]; then err_manifest_var_not .tak_server_key_filename ; fi
  if [[ "$TAK_SERVER_KEY_PASSPHRASE" == "null" ]]; then err_manifest_var_not .tak_server_key_passphrase ; fi
  if [[ "$TAK_SERVER_HOSTNAME" == "null" ]]; then err_manifest_var_not .tak_server_hostname ; fi
  if [[ "$TAK_ADMIN_CERT_FILENAME" == "null" ]]; then err_manifest_var_not .tak_admin_cert_filename ; fi
  if [[ "$TAK_ADMIN_KEY_FILENAME" == "null" ]]; then err_manifest_var_not .tak_admin_key_filename ; fi
  if [[ "$TAK_ADMIN_KEY_PASSPHRASE" == "null" ]]; then err_manifest_var_not .tak_admin_key_passphrase ; fi
  if [[ "$RM_CERT_CHAIN_FILENAME" == "null" ]]; then err_manifest_var_not .rm_cert_chain_filename ; fi
  if [[ "$RM_STARTUP_CERTS_LOCAL_FOLDER" == "null" ]]; then err_manifest_var_not .rm_startup_certs_local_folder ; fi


  # Wait for the local RM api to come up
  MAX_ATTEMPTS=240
  HEALTHCHECK_OK="no"
  for i in $(seq 1 $MAX_ATTEMPTS); 
  do 
    RESPONSE_CODE=$(curl -XGET -s -o /dev/null -I -w "%{http_code}" "$RM_LOCAL_API_HEALTCHECK_URL")

    if [[ "$RESPONSE_CODE" == "200" ]]; then 
      echo "RM healthcheck success. Moving on..."
      HEALTHCHECK_OK="ok"
      break
    fi
    echo "RM healthcheck '${RESPONSE_CODE}' != 200. Waiting '${RM_LOCAL_API_HEALTCHECK_URL}' ... $i/$MAX_ATTEMPTS"

    sleep 20
  done

  # Exit 1 if healthcheck failed
  if [[ "${HEALTHCHECK_OK}" != "ok" ]]; then
    echo "ERROR. All healthchecks failed.. Giving up..."
    exit 1
  fi

  # Now that the we 'know' that the local API is up. Wait for the goodies to come ready.
  DELIVERYCHECK_OK="no"
  for i in $(seq 1 $MAX_ATTEMPTS); 
  do 
    # 200 -> go ahead, !=200 -> wait
    RESPONSE_CODE=$(curl -XGET -s -o /dev/null -I -w "%{http_code}" "$RM_LOCAL_API_HOST/api/v1/healthcheck/delivery_status")
    
    if [[ "$RESPONSE_CODE" == "200" ]]; then 
      echo "RM has finished initializing. Staring to "
      DELIVERYCHECK_OK="ok"
      break
    fi
    echo "RM API not ready to deliver. '${RESPONSE_CODE}' != 200. Waiting for "$RM_LOCAL_API_HOST/api/v1/healthcheck/delivery_status"  $i/$MAX_ATTEMPTS"

    sleep 20
  done

  # Seed initial certificate data if necessary
  if [[ ! -d "${TR}/data/certs" ]];then
    mkdir -p "${TR}/data/certs"
  fi
  if [[ -z "$(ls -A "${TR}/data/certs")" ]];then
    echo Copying initial certificate configuration
    cp -R ${TR}/certs/* ${TR}/data/certs/
  else
    echo Using existing certificates.
  fi

  # Move original certificate data and symlink to certificate data in data dir
  if [[ ! -L "${TR}/certs"  ]];then
    mv ${TR}/certs ${TR}/certs.orig
    ln -s "${TR}/data/certs/" "${TR}/certs"
  fi

  # Symlink the log directory
  if [[ ! -L "${TR}/certs"  ]];then
    ln -s "${TR}/data/logs/" "${TR}/logs"
  fi

  #pushd /opt/tak/data/certs >> /dev/null
  pushd ${RM_STARTUP_CERTS_LOCAL_FOLDER} >> /dev/null
  
  set -x
  
  # Create takserver.p12 using certificates defined in manifest
  openssl pkcs12 -export -out takserver.p12 -inkey "${TAK_SERVER_KEY_FILENAME}" -in "${TAK_SERVER_CERT_FILENAME}" -name "${TAK_SERVER_HOSTNAME}" -passin pass:${TAK_SERVER_KEY_PASSPHRASE} -passout pass:${TAKSERVER_CERT_PASS}
  
  # Print some debug info out of takserver.p12 if needed
  # openssl pkcs12 -info -in takserver.p12 -passin pass:${TAKSERVER_CERT_PASS}

  # Create the Java keystore and import our PKCS12 for our TAK Server. I guess this is the "server certificate" used by java process..
  keytool -importkeystore -srcstoretype PKCS12 -destkeystore takserver.jks -srckeystore takserver.p12 -alias "${TAK_SERVER_HOSTNAME}" -srcstorepass "${TAKSERVER_CERT_PASS}" -deststorepass "${TAKSERVER_CERT_PASS}" -destkeypass "${TAKSERVER_CERT_PASS}"

  # Crate trust store, all the trusted CA/root certificates are dumped here. Keytool should accept certs either one by one or as a chain. -alias needs to be unique for all imports 
  ALIAS=$(openssl x509 -noout -subject -in "${RM_CERT_CHAIN_FILENAME}" |md5sum | cut -d" " -f1)
  keytool -noprompt -import -trustcacerts -file "${RM_CERT_CHAIN_FILENAME}" -alias $ALIAS -keystore takserver-truststore.jks -storepass ${TAKSERVER_CERT_PASS}
  
  mkdir -p /opt/tak/data/certs/files
  
  # Move/Copy the Java Keystore file to the TAK certificate directory
  cp -v takserver.jks /opt/tak/data/certs/files/takserver.jks

  # Move/Copy the trust store library to the TAK certificate directory
  cp -v takserver-truststore.jks /opt/tak/data/certs/files/truststore-root.jks

  # fed-truststore.jks is needed, copy truststore-root.jks
  cp -v /opt/tak/data/certs/files/truststore-root.jks /opt/tak/data/certs/files/fed-truststore.jks

  #
  # ADD ADMIN NOTES, THIS WILL BE DONE WHEN "messaging" service is started later on
  # enable_admin.sh requires admin client certificate to be in /opt/tak/certs/files/
  #
  # cp /opt/tak/certs/kissakoira123.pem /opt/tak/certs/files/kissakoira123.pem
  # ADMIN_CERT_NAME=kissakoira123 /opt/scripts/enable_admin.sh

  set -x
  popd >> /dev/null
  
  chmod -R 777 ${TR}/data/

  echo "Wait for postgres"
  WAITFORIT_TIMEOUT=60 /usr/bin/wait-for-it.sh ${POSTGRES_ADDRESS}:5432 -- true
  echo "Init db"
  java -jar ${TR}/db-utils/SchemaManager.jar -url jdbc:postgresql://${POSTGRES_ADDRESS}:5432/${POSTGRES_DB} -user ${POSTGRES_USER} -password ${POSTGRES_PASSWORD} upgrade
  
  exit 0
fi

#
# After this is the "stand alone" part. This shouldn't need the RM integrations etc... 
#

# Remove hardcoded country code
sed -i.orig "s/COUNTRY=US/COUNTRY=\${COUNTRY}/g" ${CR}/cert-metadata.sh
# Override some distribution scripts outright since doing it with sed is too painful
if [[ ! "/opt/scripts/makeCert.sh" ]];then
  mv /opt/scripts/makeCert.sh ${CR}/
fi


# Seed initial certificate data if necessary
if [[ ! -d "${TR}/data/certs" ]];then
  mkdir -p "${TR}/data/certs"
fi
if [[ -z "$(ls -A "${TR}/data/certs")" ]];then
  echo Copying initial certificate configuration
  cp -R ${TR}/certs/* ${TR}/data/certs/
else
  echo Using existing certificates.
fi

# Move original certificate data and symlink to certificate data in data dir
if [[ ! -L "${TR}/certs"  ]];then
  mv ${TR}/certs ${TR}/certs.orig
  ln -s "${TR}/data/certs/" "${TR}/certs"
fi

# Symlink the log directory
if [[ ! -L "${TR}/certs"  ]];then
  ln -s "${TR}/data/logs/" "${TR}/logs"
fi

cd ${CR}

if [[ ! -f "${CR}/files/root-ca.pem" ]];then
  CAPASS=${CA_PASS} bash makeRootCa.sh --ca-name "${CA_NAME}"
else
  echo Using existing root CA.
fi

if [[ ! -f "${CR}/files/takserver.pem" ]];then
  CAPASS=${CA_PASS} PASS="${TAKSERVER_CERT_PASS}" bash makeCert.sh server takserver
else
  echo Using existing takserver certificate.
fi

if [[ ! -f "${CR}/files/${ADMIN_CERT_NAME}.pem" ]];then
  CAPASS=${CA_PASS} PASS="${ADMIN_CERT_PASS}" bash makeCert.sh client "${ADMIN_CERT_NAME}"
else
  echo Using existing ${ADMIN_CERT_NAME} certificate.
fi

chmod -R 777 ${TR}/data/

echo "Wait for postgres"
WAITFORIT_TIMEOUT=60 /usr/bin/wait-for-it.sh ${POSTGRES_ADDRESS}:5432 -- true
echo "Init db"
java -jar ${TR}/db-utils/SchemaManager.jar -url jdbc:postgresql://${POSTGRES_ADDRESS}:5432/${POSTGRES_DB} -user ${POSTGRES_USER} -password ${POSTGRES_PASSWORD} upgrade