#!/usr/bin/env -S /bin/bash
set -e
# There does not seem to be any sensible flag for this so delete and re-add is the way
/opt/scripts/delete_user.sh
/opt/scripts/enable_user.sh
