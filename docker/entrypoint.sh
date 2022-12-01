#!/usr/bin/env -S /bin/bash
set -e
if [ "$#" -eq 0 ]; then
  . /opt/scripts/firstrun.sh
  . /opt/scripts/start.sh
else
  # run the given command
  exec "$@"
fi
