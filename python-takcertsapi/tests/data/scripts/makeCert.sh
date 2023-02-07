#!/bin/bash
echo "Hello world, makeCert here!"
usage() {
  echo "Usage: ./makeCert.sh [server|client|ca] <common name>"
  echo "  If you do not provide a common name on the command line, you will be prompted for one"
  exit -1
}

if [ "$1" ]; then
  if [ "$1" == "server" ]; then
    EXT=server
  elif [ "$1" == "client" ]; then
    EXT=client
  elif [ "$1" == "ca" ]; then
    EXT=v3_ca
  else
    usage
  fi
else
  usage
fi

if [ "$2" ];
then
  SNAME=$2
else
  echo "Please give the common name for your certificate (no spaces) as arg"
  exit 1
fi

set -e
SCRIPT_DIR=`dirname "$0"`
cd $SCRIPT_DIR
cd ../certs
PWD=`pwd` # pragma: allowlist secret

echo "Making ${SNAME} certs in ${PWD}"

echo "${PASS}" >"${SNAME}".key
echo "${PASS}" >"${SNAME}".pem
echo "${PASS}" >"${SNAME}".p12
echo "${PASS}" >"${SNAME}"-public.p12

ls
