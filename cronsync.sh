#!/usr/bin/env bash
set -euo pipefail

if [ -z "${SRC+x}" ]; then
    echo "Environment variable SRC is not set. Exiting." >&2
    exit 1
fi

if [ -z "${DST+x}" ]; then
    echo "Environment variable DST is not set. Exiting." >&2
    exit 1
fi

SRC="$SRC"
DST="$DST"


LOCKFILE="/tmp/cronsync_models.lock"

# Try to create a lockfile, exit if already running.
exec 200>"$LOCKFILE"
if ! flock -n 200; then
    echo "Sync already running. Exiting."
    exit 1
fi

echo "Syncing models from $SRC to $DST"
mkdir -p "$DST"
rsync -avH "$SRC" "$DST"
chmod go+r "$DST"

# Lock released automatically when the script exits