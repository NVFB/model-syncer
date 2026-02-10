#!/bin/sh
set -eu

CRONTAB_PATH="/etc/crontabs/root"

write_crontab_from_env() {
  : "${CRON_SCHEDULE:=}"
  : "${CRON_COMMAND:=}"

  if [ -z "$CRON_COMMAND" ]; then
    # Run via bash explicitly to avoid cron using /bin/sh
    CRON_COMMAND="/usr/local/bin/cronsync.sh"
  fi

  # Default schedule: every hour at minute 0
  if [ -z "$CRON_SCHEDULE" ]; then
    CRON_SCHEDULE="0 * * * *"
  fi

  cat >"$CRONTAB_PATH" <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Schedule can be set at runtime with CRON_SCHEDULE (default: 0 * * * *)
# Job output is redirected to container stdout/stderr.
${CRON_SCHEDULE} SRC="${SRC}" DST="${DST}" ${CRON_COMMAND} >>/proc/1/fd/1 2>&1
EOF
}

install_crontab() {
  : "${CRONTAB_FILE:=}"
  : "${CRONTAB:=}"

  mkdir -p /etc/crontabs

  if [ -n "$CRONTAB_FILE" ]; then
    if [ ! -f "$CRONTAB_FILE" ]; then
      echo "CRONTAB_FILE points to a non-existent file: $CRONTAB_FILE" >&2
      exit 2
    fi
    cp "$CRONTAB_FILE" "$CRONTAB_PATH"
  elif [ -n "$CRONTAB" ]; then
    printf "%s\n" "$CRONTAB" >"$CRONTAB_PATH"
  else
    write_crontab_from_env
  fi

  # Alpine expects root crontab at /etc/crontabs/root with tight perms.
  chmod 600 "$CRONTAB_PATH" || true
}

maybe_run_on_start() {
  : "${RUN_ON_START:=0}"
  if [ "$RUN_ON_START" = "1" ] || [ "$RUN_ON_START" = "true" ]; then
    echo "RUN_ON_START enabled; running sync once now."
    /usr/local/bin/cronsync.sh
  fi
}

install_crontab
maybe_run_on_start

echo "Installed crontab at $CRONTAB_PATH:"
sed -n '1,200p' "$CRONTAB_PATH" || true

# Use tini as the init system to properly reap zombies and forward signals.
# Run cron in foreground; force crontab directory; log to stdout.
exec tini -- crond -f -c /etc/crontabs -l 8 -L /dev/stdout

