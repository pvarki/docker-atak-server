#!/usr/bin/env -S /bin/bash
set -e
TR=/opt/tak

# Clean shutdowns
MESSAGING_PID=null
API_PID=null
PM_PID=null
kill() {
  if [ $MESSAGING_PID != null ];then
    kill $MESSAGING_PID
    MESSAGING_PID=null
  fi
  if [ $API_PID != null ];then
    kill $API_PID
    API_PID=null
  fi
  if [ $PM_PID != null ];then
    kill $PM_PID
    PM_PID=null
  fi
}
trap kill SIGINT
trap kill SIGTERM

# Create config
cat /opt/templates/CoreConfig.tpl | gomplate >${TR}/CoreConfig.xml

# Change to workdir
cd ${TR}

# This will set bunch of variables
. ./setenv.sh

# Start the processes
java -jar -Xmx${MESSAGING_MAX_HEAP}m -Dspring.profiles.active=messaging takserver.war &
MESSAGING_PID=$!
java -jar -Xmx${API_MAX_HEAP}m -Dspring.profiles.active=api -Dkeystore.pkcs12.legacy takserver.war &
API_PID=$!
java -jar -Xmx${PLUGIN_MANAGER_MAX_HEAP}m takserver-pm.jar &
PM_PID=$!

# TODO: make sure admin user is enabled

# Wait for the java processes to exit
while [ $MESSAGING_PID != null ]
do
  sleep 1
done
