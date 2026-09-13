#!/usr/bin/env bash
set -e
cd /opt/tak
. ./setenv.sh

exec /usr/bin/python3 /opt/scripts/user_manager.py "$@"
