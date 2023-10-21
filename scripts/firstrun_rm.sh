#!/usr/bin/env -S /bin/bash
TR=/opt/tak
CR=${TR}/certs

# Symlink the log directory under data dir
if [[ ! -d "${TR}/data/logs" ]];then
  mkdir -p "${TR}/data/logs"
fi
if [[ ! -L "${TR}/logs"  ]];then
  ln -f -s "${TR}/data/logs/" "${TR}/logs"
fi

# Seed initial certificate data if necessary
if [[ ! -d "${TR}/data/certs" ]];then
  mkdir -p "${TR}/data/certs"
fi
# Move original certificate data and symlink to certificate data in data dir
if [[ ! -L "${TR}/certs"  ]];then
  mv ${TR}/certs ${TR}/certs.orig
  ln -f -s "${TR}/data/certs/" "${TR}/certs"
fi

echo "FIXME: Get CA cert from RASENMAEHER (hint: look in /ca_public)"
echo "FIXME: Get LE (or mkcert) cert from KRAFTWERK (hint: look at /le_certs)"


set -e
echo "Wait for postgres"
WAITFORIT_TIMEOUT=60 /usr/bin/wait-for-it.sh ${POSTGRES_ADDRESS}:5432 -- true
echo "Init db"
# This requires postgres superuser privileges which we do not want to actually give to tak containers
# java -jar ${TR}/db-utils/SchemaManager.jar -url jdbc:postgresql://${POSTGRES_ADDRESS}:5432/${POSTGRES_DB} -user ${POSTGRES_SUPERUSER} -password ${POSTGRES_SUPER_PASSWORD} upgrade
# First import base SQL file to get base migration state
PGPASSWORD=${POSTGRES_PASSWORD} psql -v ON_ERROR_STOP=1 -h ${POSTGRES_ADDRESS} -U ${POSTGRES_USER} ${POSTGRES_DB} --single-transaction --file /opt/scripts/takdb_base.sql
# Then if there are any un-applied migrations apply them.
java -jar ${TR}/db-utils/SchemaManager.jar -url jdbc:postgresql://${POSTGRES_ADDRESS}:5432/${POSTGRES_DB} -user ${POSTGRES_USER} -password ${POSTGRES_PASSWORD} upgrade
