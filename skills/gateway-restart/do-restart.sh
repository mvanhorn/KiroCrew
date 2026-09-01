#!/bin/bash
# Delayed gateway restart — run as a disowned process.
# The sleep gives the calling session time to finish responding.
#
# The CLI restart verb verifies the replacement gateway is serving and exits
# non-zero when it is not — but a disowned process discards both its output
# and its exit status. Record them instead: output appends to restart.log and
# the exit status lands in restart-status, both under the crew logs dir, so
# the calling agent can verify the outcome on its next turn (see SKILL.md
# "Verify the outcome").
LOG_DIR="${KIROCREW_HOME:-$HOME/.kiro/crew}/logs"
# Attempt-specific when the scheduler passes one (SKILL.md step 3 generates a
# per-attempt path), so overlapping restart attempts cannot overwrite each
# other's verdict; the shared default serves a lone attempt.
STATUS_FILE="${KIROCREW_RESTART_STATUS_FILE:-$LOG_DIR/restart-status}"
# The diagnostic log is correlated with the attempt the same way: derived from
# the attempt's status file, so a failed attempt's verifier never quotes
# another attempt's output or remedy out of a shared log.
if [ -n "${KIROCREW_RESTART_LOG_FILE:-}" ]; then
  LOG_FILE="$KIROCREW_RESTART_LOG_FILE"
elif [ -n "${KIROCREW_RESTART_STATUS_FILE:-}" ]; then
  LOG_FILE="$KIROCREW_RESTART_STATUS_FILE.log"
else
  LOG_FILE="$LOG_DIR/restart.log"
fi
umask 077
mkdir -p "$LOG_DIR"
# Remove the previous outcome BEFORE the delay: while the file is absent a
# restart attempt is pending; once it exists it names the exit status of the
# most recent attempt. A stale success left in place would be read as this
# attempt's verdict.
rm -f "$STATUS_FILE"
sleep "${KIROCREW_RESTART_DELAY:-10}"
# The restart verb prints a fresh dashboard token URL on success; the skill
# tells the resumed agent to quote this log into the conversation, so redact
# the bearer token on the way in. PIPESTATUS keeps the restart's own exit
# status — plain $? would report sed's.
kirocrew restart 2>&1 | sed -E 's/([?&]token=)[^[:space:]]+/\1REDACTED/g' >>"$LOG_FILE"
status="${PIPESTATUS[0]}"
printf '%s\n' "$status" >"$STATUS_FILE"
exit "$status"
