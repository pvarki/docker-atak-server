#!/usr/bin/env -S /bin/bash
set -e
TR=/opt/tak
CR=${TR}/certs
ZIPTGT=${CR}/files/clientpkgs

mkdir -p ${ZIPTGT}
if [ -z "$CLIENT_CERT_NAME" ]
then
  echo "CLIENT_CERT_NAME not set"
  exit 1
fi
export CLIENT_CERT_PASSWORD=`pwgen -cn1 20 1`  # pragma: allowlist secret

tmp_dir=$(mktemp -d "/tmp/newclient.XXXXXXXX")
WORK_DIR=$tmp_dir"/"$CLIENT_CERT_NAME
mkdir -p $WORK_DIR
cp -R /opt/templates/missionpkg/* $WORK_DIR/
cat ${WORK_DIR}/content/blueteam.pref.tpl | gomplate >${WORK_DIR}/content/blueteam.pref
cat ${WORK_DIR}/MANIFEST/manifest.xml.tpl | gomplate >${WORK_DIR}/MANIFEST/manifest.xml
rm ${WORK_DIR}/content/blueteam.pref.tpl ${WORK_DIR}/MANIFEST/manifest.xml.tpl

cd ${CR}
CAPASS=${CA_PASS} PASS="${CLIENT_CERT_PASSWORD}" bash makeCert.sh client "${CLIENT_CERT_NAME}"
cp ${CR}/files/${CLIENT_CERT_NAME}.p12 ${WORK_DIR}/content/
cp ${CR}/files/takserver-public.p12 ${WORK_DIR}/content/

cd $WORK_DIR
zip -r ${ZIPTGT}/${CLIENT_CERT_NAME}.zip ./
rm -rf $tmp_dir
