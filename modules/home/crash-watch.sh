# shellcheck shell=bash
# Follows systemd-coredump entries in the journal and offers an AI diagnosis.
# Environment: MARCHYO_CRASH_IGNORE_FILE (file holding an extended regex on the
# executable's basename), MARCHYO_CRASH_DEDUPE_SECONDS, MARCHYO_CRASH_MAX_PER_MINUTE,
# MARCHYO_CRASH_MAX_OFFERS (concurrent notifications).
set -uo pipefail

# See systemd.journal-fields(7).
readonly COREDUMP_MESSAGE_ID=fc2e22bc6ee647b6b90729ab34a250b1

dedupe_seconds=${MARCHYO_CRASH_DEDUPE_SECONDS:-60}
max_per_minute=${MARCHYO_CRASH_MAX_PER_MINUTE:-3}
max_offers=${MARCHYO_CRASH_MAX_OFFERS:-5}

# The pattern travels in a file: systemd Environment= mangles backslashes, % and
# spaces.
ignore_pattern=
if [[ -n ${MARCHYO_CRASH_IGNORE_FILE:-} && -r $MARCHYO_CRASH_IGNORE_FILE ]]; then
  ignore_pattern=$(<"$MARCHYO_CRASH_IGNORE_FILE")
fi
if [[ -n $ignore_pattern ]]; then
  # =~ returns 2 for a regex that does not compile.
  { [[ "" =~ $ignore_pattern ]]; } 2>/dev/null
  if (($? == 2)); then
    echo "marchyo-crash-watch: ignoring invalid marchyo.ai.crashCapture.ignore: $ignore_pattern" >&2
    ignore_pattern=
  fi
fi

declare -A last_notified
offer_times=()

# notify-send renders markup in the summary and body. The replacements are
# quoted: bash 5.2 expands an unquoted & to the matched text.
escape() {
  local s=$1
  s=${s//&/"&amp;"}
  s=${s//</"&lt;"}
  s=${s//>/"&gt;"}
  printf '%s' "$s"
}

# Runs in the background: notify-send blocks until the notification is closed
# or an action is chosen, and the journal must keep being read meanwhile. The
# details travel as discrete argv words, so a hostile process name is never
# reparsed as a command.
offer() {
  local name=$1 pid=$2 exe=$3 signal=$4 timestamp=$5 action
  action=$(notify-send --app-name=marchyo --urgency=critical --expire-time=0 --wait \
    --action=diagnose=Diagnose "Process crashed: $(escape "$name")" \
    "$(escape "$signal") (PID $pid)") || return 0
  [[ $action == diagnose ]] || return 0
  marchyo agent crash -- "$pid" "$name" "$exe" "$signal" "$timestamp"
}

# Drops bookkeeping that can no longer suppress or limit anything.
prune() {
  local now=$1 key seen t kept=()
  for key in "${!last_notified[@]}"; do
    seen=${last_notified[$key]}
    ((now - seen >= dedupe_seconds)) && unset "last_notified[$key]"
  done
  for t in "${offer_times[@]}"; do
    ((now - t < 60)) && kept+=("$t")
  done
  offer_times=("${kept[@]}")
}

handle() {
  local entry=$1 uid comm pid exe signal timestamp name key now seen running
  # A dash stands for an empty or missing field: tab is IFS whitespace, so an
  # empty field would collapse into the next delimiter and shift the rest.
  # systemd-coredump logs the entry itself; _SYSTEMD_UNIT is set by journald and
  # cannot be forged, unlike a message any process of this user can write.
  IFS=$'\t' read -r uid comm pid exe signal timestamp < <(
    jq -r 'def field: if . == null or . == "" then "-" else . end;
           select((._SYSTEMD_UNIT // "") | startswith("systemd-coredump@"))
           | [(._UID | field),
              (.COREDUMP_COMM | field),
              (.COREDUMP_PID | field),
              (.COREDUMP_EXE | field),
              (.COREDUMP_SIGNAL_NAME | field),
              (.COREDUMP_TIMESTAMP | field)] | @tsv' <<<"$entry" 2>/dev/null
  )

  [[ ${pid:-} =~ ^[0-9]+$ ]] || return 0
  [[ $timestamp =~ ^[0-9]+$ ]] || timestamp=

  # Only this user's crashes; a daemon dumping core is a sysadmin's problem.
  [[ $uid =~ ^[0-9]+$ ]] || return 0
  ((uid == UID)) || return 0

  # comm is truncated to 15 characters, so prefer the executable's basename.
  name=$comm
  [[ $exe == /* ]] && name=${exe##*/}
  name=${name##*/}
  [[ -n $name && $name != "-" && $name != "." && $name != ".." ]] || name=unknown
  name=${name:0:128}

  [[ -n $ignore_pattern && $name =~ $ignore_pattern ]] && return 0

  # Never announce our own machinery.
  [[ $name == marchyo-crash-* || $name == marchyo-agent-* ]] && return 0

  # Safe as an associative-array subscript; collisions only merge dedupe slots.
  key=${name//[^A-Za-z0-9._+-]/_}
  now=$EPOCHSECONDS
  prune "$now"
  seen=${last_notified[$key]:-0}
  ((now - seen < dedupe_seconds)) && return 0

  # A burst of distinct programs must not bury the desktop or the machine.
  ((${#offer_times[@]} >= max_per_minute)) && return 0
  running=$(jobs -rp | wc -l)
  ((running >= max_offers)) && return 0

  last_notified[$key]=$now
  offer_times+=("$now")
  offer "$name" "$pid" "$exe" "$signal" "$timestamp" &
}

# -n 0 so a restart does not announce crashes that were already dealt with.
journalctl -f -n 0 -o json "MESSAGE_ID=$COREDUMP_MESSAGE_ID" 2>/dev/null |
  {
    while IFS= read -r entry; do
      handle "$entry"
    done
    wait
  }
