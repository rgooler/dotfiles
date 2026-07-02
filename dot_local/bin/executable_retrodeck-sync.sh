#!/usr/bin/env bash
# Set-and-forget two-way sync of RetroDECK game saves between a Linux device
# (Steam Deck or desktop) and the home garage S3 bucket, using rclone bisync.
#
# It syncs two independent pairs:
#   ~/retrodeck/saves  <=>  garage:<BUCKET>/saves
#   ~/retrodeck/states <=>  garage:<BUCKET>/states
# Each pair keeps its own bisync state (--workdir) and its own first-run
# sentinel so the two never interfere.
#
# Designed to be driven by systemd user units (retrodeck-sync-watch.service
# runs a recursive inotify watch on the save dirs, retrodeck-sync.timer is a
# ~15m safety net), but it is safe to run by hand too. See
# docs/steamdeck-saves.md for the full runbook.
#
# Requires: rclone (>= 1.66 for a mature bisync + --conflict-resolve), flock,
#           and inotifywait (the 'inotify-tools' package) for --watch mode.
#
# Usage:
#   retrodeck-sync.sh            # normal debounced sync (what systemd runs)
#   retrodeck-sync.sh --timer    # skip the debounce settle (timer safety-net)
#   retrodeck-sync.sh --watch    # recursive inotify watcher: watch the save
#                                 #   dirs (deep, unlike a systemd .path unit)
#                                 #   and fire a debounced sync on any change.
#                                 #   This is what retrodeck-sync-watch.service
#                                 #   runs. Needs the 'inotify-tools' package.
#   retrodeck-sync.sh --resync   # force a --resync on the NEXT run of each pair
#                                 #   (deletes the sentinels, then re-establishes
#                                 #    the bisync baseline; use to recover)
#   retrodeck-sync.sh --dry-run  # pass --dry-run to rclone, change nothing
#   retrodeck-sync.sh --help
#
# Config (override via environment, e.g. in the systemd unit or ~/.config):
#   RCLONE_REMOTE   rclone remote name for garage           (default: garage)
#   BUCKET          garage bucket holding saves/ and states/(default: retrodeck-saves)
#   SAVES_DIR       local saves dir            (default: $HOME/retrodeck/saves)
#   STATES_DIR      local save-states dir      (default: $HOME/retrodeck/states)
#   DEBOUNCE_SECS   settle before a watch-triggered sync    (default: 25)
#   RCLONE_TIMEOUT  per-operation timeout passed to rclone  (default: 5m)

set -euo pipefail

# ---- config -----------------------------------------------------------------
RCLONE_REMOTE="${RCLONE_REMOTE:-garage}"
BUCKET="${BUCKET:-retrodeck-saves}"
SAVES_DIR="${SAVES_DIR:-$HOME/retrodeck/saves}"
STATES_DIR="${STATES_DIR:-$HOME/retrodeck/states}"
DEBOUNCE_SECS="${DEBOUNCE_SECS:-25}"
RCLONE_TIMEOUT="${RCLONE_TIMEOUT:-5m}"

# State/log/lock live under $HOME so they survive SteamOS updates (which wipe
# /usr) and don't need root.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/retrodeck-sync"
LOG_FILE="${STATE_DIR}/retrodeck-sync.log"
LOCK_FILE="${STATE_DIR}/retrodeck-sync.lock"

# ---- arg parsing ------------------------------------------------------------
TIMER_RUN="false"   # --timer: this run came from the safety-net timer
WATCH="false"       # --watch: run the recursive inotify watcher, not a sync
FORCE_RESYNC="false"
DRY_RUN=()          # array so it expands to nothing when unset

usage() {
  # Print the header comment block (the lines after the shebang, up to but not
  # including `set -euo pipefail`) as help text.
  sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p}' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timer)   TIMER_RUN="true" ;;
    --watch)   WATCH="true" ;;
    --resync)  FORCE_RESYNC="true" ;;
    --dry-run) DRY_RUN=(--dry-run) ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$STATE_DIR"

# ---- logging ----------------------------------------------------------------
# Everything we log() goes to journald (stdout, captured by the systemd unit)
# AND to a size-capped logfile in $STATE_DIR. rclone writes its own detail to
# the same logfile via --log-file below.
log() { printf '%s %s\n' "$(date -Is)" "$*" | tee -a "$LOG_FILE" ; }

# Trim the logfile if it grows past ~5 MiB (keep the last ~2000 lines). Cheap
# poor-man's rotation so we never fill a Deck's home partition.
rotate_log() {
  [[ -f "$LOG_FILE" ]] || return 0
  local size
  size=$(stat -c '%s' "$LOG_FILE" 2>/dev/null || echo 0)
  if (( size > 5 * 1024 * 1024 )); then
    tail -n 2000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    log "rotated logfile (was ${size} bytes)"
  fi
}

# ---- watch mode -------------------------------------------------------------
# Recursive inotify watcher (retrodeck-sync-watch.service runs this). A systemd
# .path unit only fires on changes to the *named* dir, NOT its subdirs, and
# RetroDECK writes saves into per-emulator subfolders — so we use `inotifywait
# -r` to see writes at any depth. Each event (re)arms a settle timer; only a
# DEBOUNCE_SECS-long quiet gap actually triggers a sync (via `--timer`, since
# we've already debounced here). The triggered run takes the flock below and
# coalesces with the safety timer. This mode NEVER takes the sync lock itself,
# so it can run forever without blocking syncs — hence it returns before the
# flock acquisition.
run_watch() {
  command -v inotifywait >/dev/null 2>&1 || {
    log "ERROR: --watch needs inotifywait (install the 'inotify-tools' package)"; exit 1; }
  mkdir -p "$SAVES_DIR" "$STATES_DIR"
  log "watch: recursive inotify on ${SAVES_DIR} and ${STATES_DIR} (debounce ${DEBOUNCE_SECS}s)"
  local timer_pid=""
  # -m keep monitoring, -r recursive, -q quiet. close_write/create/delete/move
  # are the events that mean "a save file actually changed".
  inotifywait -mrq \
      -e close_write -e create -e delete -e move \
      "$SAVES_DIR" "$STATES_DIR" | while read -r _; do
    # Cancel any pending settle and re-arm it, so the sync fires DEBOUNCE_SECS
    # after the LAST event in a burst, not the first.
    if [[ -n "$timer_pid" ]]; then kill "$timer_pid" 2>/dev/null || true; fi
    ( sleep "$DEBOUNCE_SECS"; "$0" --timer >/dev/null 2>&1 || true ) &
    timer_pid=$!
  done
}

if [[ "$WATCH" == "true" ]]; then
  run_watch
  exit 0
fi

# ---- concurrency ------------------------------------------------------------
# Grab an exclusive, NON-blocking lock. If another run holds it (a watch-driven
# sync fired while the .timer is mid-sync, say) we exit cleanly instead of
# stacking a second rclone on the same state dir — the running sync already
# covers the latest on-disk state, so coalescing is correct, not lossy.
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "another retrodeck-sync is already running; skipping this trigger"
  exit 0
fi

# ---- preflight --------------------------------------------------------------
for cmd in rclone flock; do
  command -v "$cmd" >/dev/null 2>&1 || { log "ERROR: required tool '$cmd' not in PATH"; exit 1; }
done

rotate_log

# Handle --resync: clear the per-pair sentinels so each pair re-baselines this
# run. (We don't just add --resync unconditionally; that's destructive.)
if [[ "$FORCE_RESYNC" == "true" ]]; then
  log "--resync requested: clearing sentinels so each pair re-baselines"
  rm -f "${STATE_DIR}"/*.initialized
fi

# ---- debounce ---------------------------------------------------------------
# A single save-write often lands as a burst of file events. Sleep briefly so
# the burst coalesces into one sync. Skip the settle for timer-driven runs
# (already spaced out — and watch-driven runs arrive via --timer, since the
# watcher does its own debounce) and for dry-runs.
if [[ "$TIMER_RUN" == "false" && ${#DRY_RUN[@]} -eq 0 && "$DEBOUNCE_SECS" -gt 0 ]]; then
  log "debounce: settling ${DEBOUNCE_SECS}s before sync"
  sleep "$DEBOUNCE_SECS"
fi

# ---- the sync ---------------------------------------------------------------
FAILED=0

sync_pair() {
  # sync_pair NAME LOCAL_DIR
  # Bisync LOCAL_DIR against garage:<BUCKET>/NAME, with its own state + sentinel.
  local name="$1" local_dir="$2"
  local remote="${RCLONE_REMOTE}:${BUCKET}/${name}"
  local workdir="${STATE_DIR}/bisync-${name}"
  local sentinel="${STATE_DIR}/${name}.initialized"

  if [[ ! -d "$local_dir" ]]; then
    log "WARN: local dir '${local_dir}' for pair '${name}' does not exist yet; creating it"
    mkdir -p "$local_dir"
  fi
  # rclone bisync aborts with "empty prior listing" as a data-loss guard when a
  # side is empty. A fresh, save-less device (no games played yet) would hit
  # this on every run after the first. Keep a tiny placeholder so the baseline
  # is never empty; it syncs harmlessly, and genuine emptiness protection stays
  # intact for dirs that actually held saves.
  [[ -e "$local_dir/.keep" ]] || : > "$local_dir/.keep"
  mkdir -p "$workdir"

  # First run for this pair: --resync establishes the baseline (makes both
  # sides consistent and records a listing). rclone bisync REFUSES to run
  # without an existing baseline, so the very first sync MUST be a resync. We
  # guard it with the sentinel so a normal run never resyncs — an unguarded
  # --resync can overwrite one side with the other and wipe saves. See the
  # bootstrap order in the runbook.
  local resync=()
  if [[ ! -f "$sentinel" ]]; then
    log "pair '${name}': first run — doing --resync to establish baseline"
    resync=(--resync)
  fi

  # Flag rationale:
  #  --conflict-resolve newer   Emulator saves are opaque binaries; there is no
  #                             sane 3-way merge. "Newest mtime wins" matches a
  #                             single player hopping between devices.
  #  --conflict-loser pathname  Don't discard the loser — rename it alongside...
  #  --conflict-suffix .conflict-{DateOnly}
  #                             ...as <file>.conflict-YYYY-MM-DD, a manual-restore
  #                             safety net so "newest wins" never silently loses.
  #  --resilient --recover      Auto-recover from an interrupted prior run
  #                             instead of demanding a manual --resync.
  #  --max-lock 15m             Bisync drops a lock in its workdir; if a run
  #                             dies, this bounds how long a stale lock blocks
  #                             the next run before it is auto-broken.
  #  --compare size,modtime     Deterministic change detection for binaries.
  local rc=0
  rclone bisync "$local_dir" "$remote" \
      "${resync[@]}" \
      "${DRY_RUN[@]}" \
      --workdir "$workdir" \
      --conflict-resolve newer \
      --conflict-loser pathname \
      --conflict-suffix ".conflict-{DateOnly}" \
      --compare size,modtime \
      --resilient \
      --recover \
      --max-lock 15m \
      --timeout "$RCLONE_TIMEOUT" \
      --transfers 4 \
      --log-file "$LOG_FILE" \
      --log-level INFO || rc=$?

  if [[ "$rc" -eq 0 ]]; then
    log "pair '${name}': sync OK"
    # Only mark initialized on a real (non-dry-run) success, so a --dry-run can
    # never trick a pair into skipping its real first --resync.
    if [[ ${#DRY_RUN[@]} -eq 0 && ! -f "$sentinel" ]]; then
      : > "$sentinel"
      log "pair '${name}': baseline established (sentinel written)"
    fi
  else
    log "ERROR: pair '${name}': rclone bisync exited ${rc}"
    FAILED=1
  fi
}

log "=== retrodeck-sync start (remote=${RCLONE_REMOTE} bucket=${BUCKET}${DRY_RUN:+ dry-run}) ==="
sync_pair "saves"  "$SAVES_DIR"
sync_pair "states" "$STATES_DIR"
log "=== retrodeck-sync done (failed=${FAILED}) ==="

exit "$FAILED"
