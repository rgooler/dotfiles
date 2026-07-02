#!/usr/bin/env bash
# Point-in-time snapshot backups of the RetroDECK saves/states, so you can roll
# back a corrupted save. Uses restic into a repo that lives at the `restic/`
# prefix of the same garage bucket (reached via the existing rclone remote), so
# it reuses the garage creds and only needs its own password. Independent of the
# bisync sync path — a bad sync can't corrupt the backup history.
#
# Driven by retrodeck-backup.timer (~30m) but safe to run by hand. Rollback:
#   restic snapshots                         # list; note the ID you want
#   restic restore <id> --target /tmp/roll   # restore to a scratch dir, then
#                                            #   copy the files you want back in
# (export the same RESTIC_* env, or run this script's env: see below.)
#
# Requires: restic, rclone (with the 'garage' remote), flock.
#
# Config (env-overridable, e.g. in the systemd unit):
#   RESTIC_REPOSITORY     restic repo         (default: rclone:garage:retrodeck-saves/restic)
#   RESTIC_PASSWORD_FILE  restic password     (default: ~/.config/retrodeck-sync/restic-password)
#   SAVES_DIR / STATES_DIR  dirs to snapshot  (default: ~/retrodeck/{saves,states})
#   KEEP_LAST / KEEP_DAILY  retention         (default: 20 / 7)

set -euo pipefail

# Find a per-user rclone/restic (the SteamOS/immutable fallbacks live here).
export PATH="$HOME/.local/bin:$PATH"

RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-rclone:garage:retrodeck-saves/restic}"
RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-$HOME/.config/retrodeck-sync/restic-password}"
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE
SAVES_DIR="${SAVES_DIR:-$HOME/retrodeck/saves}"
STATES_DIR="${STATES_DIR:-$HOME/retrodeck/states}"
KEEP_LAST="${KEEP_LAST:-20}"
KEEP_DAILY="${KEEP_DAILY:-7}"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/retrodeck-sync"
LOG_FILE="${STATE_DIR}/retrodeck-backup.log"
LOCK_FILE="${STATE_DIR}/retrodeck-backup.lock"
mkdir -p "$STATE_DIR"
log() { printf '%s %s\n' "$(date -Is)" "$*" | tee -a "$LOG_FILE" ; }

command -v restic >/dev/null 2>&1 || { log "ERROR: restic not on PATH"; exit 1; }
command -v rclone >/dev/null 2>&1 || { log "ERROR: rclone not on PATH (restic uses it as the backend)"; exit 1; }
[ -r "$RESTIC_PASSWORD_FILE" ] || { log "ERROR: restic password file not readable: $RESTIC_PASSWORD_FILE"; exit 1; }

# Single-flight: don't stack two restic runs on the same repo (they'd fight the
# repo lock). If one is already running, this trigger coalesces away.
exec 9>"$LOCK_FILE"
if ! flock -n 9; then log "another retrodeck-backup is already running; skipping"; exit 0; fi

# Nothing to snapshot yet? (dirs absent on a brand-new box before the first sync)
if [[ ! -d "$SAVES_DIR" && ! -d "$STATES_DIR" ]]; then
  log "no saves/states dirs yet — nothing to back up"; exit 0
fi

# Initialize the repo on first use (idempotent: only inits if not already there).
if ! restic cat config >/dev/null 2>&1; then
  log "initializing restic repo at ${RESTIC_REPOSITORY}"
  restic init >>"$LOG_FILE" 2>&1 || { log "ERROR: restic init failed"; exit 1; }
fi

log "=== retrodeck-backup start (repo=${RESTIC_REPOSITORY}) ==="
# Fixed --host so snapshots from every device form ONE series (so --keep-last
# means "last N across all devices", not N per machine).
if restic backup --host retrodeck --tag retrodeck "$SAVES_DIR" "$STATES_DIR" >>"$LOG_FILE" 2>&1; then
  log "backup OK"
else
  log "ERROR: restic backup failed (see $LOG_FILE)"; exit 1
fi

if restic forget --host retrodeck --keep-last "$KEEP_LAST" --keep-daily "$KEEP_DAILY" --prune >>"$LOG_FILE" 2>&1; then
  log "forget/prune OK (keep-last=${KEEP_LAST} keep-daily=${KEEP_DAILY})"
else
  log "WARN: restic forget/prune failed (backup itself succeeded)"
fi
log "=== retrodeck-backup done ==="
