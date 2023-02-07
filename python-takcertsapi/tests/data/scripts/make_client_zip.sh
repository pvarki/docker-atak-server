#!/usr/bin/env -S /bin/bash
set -e
if [ -z "$CLIENT_CERT_NAME" ]
then
  echo "CLIENT_CERT_NAME not set"
  exit 1
fi
if [ -z "$ZIPTGT" ]
then
  echo "ZIPTGT not set"
  exit 1
fi
tmp_dir=$(mktemp -d "/tmp/newclient.XXXXXXXX")
cd $tmp_dir
echo `date -u +"%Y%m%d-%H%M"` >./dummy.txt
zip -r ${ZIPTGT}/${CLIENT_CERT_NAME}.zip ./
rm -rf $tmp_dir
