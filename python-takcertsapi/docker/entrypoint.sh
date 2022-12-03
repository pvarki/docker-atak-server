#!/usr/bin/env -S /bin/bash
set -e
if [ "$#" -eq 0 ]; then
  exec gunicorn takcertsapi.api:APP --bind 0.0.0.0:8000 -w 4 -k uvicorn.workers.UvicornWorker
else
  exec "$@"
fi
