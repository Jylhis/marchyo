# shellcheck shell=bash
# Follows "unit entered failed state" entries in the journal and sends a
# notification with a Show log action.
# Environment: MARCHYO_UNIT_FAILURE_IGNORE_FILE (one shell glob per line, matched
# against the full unit name), MARCHYO_UNIT_FAILURE_DEDUPE_SECONDS.
set -uo pipefail

# SD_MESSAGE_UNIT_FAILED_RESULT, "Unit failed" in systemd.catalog. System units
# log it with UNIT, user units with USER_UNIT; both carry UNIT_RESULT.
# See systemd.journal-fields(7).
readonly UNIT_FAILED_MESSAGE_ID=d9b373ed55a64feb8242e02dbe79a49c
readonly SELF_UNIT=marchyo-unit-failure-watch.service

# The Show log action runs later, from the notification daemon: give it the
# absolute path. `marchyo launch terminal` picks the terminal that exists.
marchyo_bin=$(command -v marchyo)

dedupe_seconds=${MARCHYO_UNIT_FAILURE_DEDUPE_SECONDS:-60}

# The globs travel in a file: systemd Environment= mangles backslashes, % and
# spaces.
ignore_globs=()
if [[ -n ${MARCHYO_UNIT_FAILURE_IGNORE_FILE:-} && -r $MARCHYO_UNIT_FAILURE_IGNORE_FILE ]]; then
  while IFS= read -r glob || [[ -n $glob ]]; do
    if [[ -n $glob ]]; then
      ignore_globs+=("$glob")
    fi
  done <"$MARCHYO_UNIT_FAILURE_IGNORE_FILE"
fi

declare -A last_notified

ignored() {
  local name=$1 glob
  for glob in "${ignore_globs[@]}"; do
    # The unquoted right-hand side is the point: it is a glob.
    # shellcheck disable=SC2053
    if [[ $name == $glob ]]; then
      return 0
    fi
  done
  return 1
}

# Unit names come from the journal, where any process of this user can write.
# They travel only as argv words, never through eval or an unquoted expansion.
announce() {
  local unit=$1 result=$2 scope=$3 key=$4 now=$5
  local log=(journalctl -b)
  if [[ $scope == user ]]; then
    log+=(--user)
  fi
  log+=(-u "$unit")
  last_notified[$key]=$now
  marchyo notify -u critical --app-name marchyo "$unit failed" "$result" \
    --action "Show log" "$marchyo_bin" launch terminal -- "${log[@]}" || true
}

handle() {
  local entry=$1 scope unit result now key
  # Fields are joined with the unit separator, not @tsv: @tsv doubles the
  # backslash of an escaped unit name such as dev-disk-by\x2duuid-1.swap.
  IFS=$'\037' read -r scope unit result < <(
    jq -r --arg uid "$UID" '
      def field: if . == null or . == "" then "-" else . end;
      (if .USER_UNIT then "user" else "system" end) as $scope
      # UNIT and USER_UNIT are fields any process can log; _PID and _UID are set
      # by journald. A system failure comes from PID 1. A reader of the full
      # journal also sees other accounts: only the units of this user count.
      | (if $scope == "user" then ._UID == $uid else ._PID == "1" and ._UID == "0" end) as $trusted
      | (if $trusted then (.USER_UNIT // .UNIT) else null end) as $unit
      | [$scope, ($unit | field), (.UNIT_RESULT | field)] | join("\u001f")' \
      <<<"$entry" 2>/dev/null
  ) || return 0

  if [[ -z ${unit:-} || $unit == "-" ]]; then
    return 0
  fi
  # Never announce our own machinery.
  if [[ $scope == user && $unit == "$SELF_UNIT" ]]; then
    return 0
  fi
  if [[ ${result:-} == "-" || -z ${result:-} ]]; then
    result=failed
  fi
  if ignored "$unit"; then
    return 0
  fi

  # Safe as an associative-array subscript; collisions only merge dedupe slots.
  key=$scope:${unit//[^A-Za-z0-9._@:+-]/_}
  now=$EPOCHSECONDS
  if ((now - ${last_notified[$key]:-0} < dedupe_seconds)); then
    return 0
  fi
  announce "$unit" "$result" "$scope" "$key" "$now"
}

# Neither --user nor --system: journalctl merges every journal this user can
# read. Without journal group access that is only the user's own journal, so
# only user-unit failures show up. That is the accepted fallback.
# -n 0 so a restart does not announce failures that were already dealt with.
journalctl -f -n 0 -o json "MESSAGE_ID=$UNIT_FAILED_MESSAGE_ID" 2>/dev/null |
  while IFS= read -r entry; do
    handle "$entry"
  done
