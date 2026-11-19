# shellcheck shell=bash
# Restarts a hung Hyprland: probes it with hyprctl, and after repeated misses
# saves evidence and kills it so the session returns to the greeter.
# `--now` skips the probe and rescues once (from a text console or over SSH).
# Environment (all optional): MARCHYO_COMPOSITOR_WATCH_INTERVAL, _PROBE_TIMEOUT,
# _MISSES, _MAX_GAP, _GRACE (seconds), _COMM (glob on the process name).
set -uo pipefail

interval=${MARCHYO_COMPOSITOR_WATCH_INTERVAL:-10}
probe_timeout=${MARCHYO_COMPOSITOR_WATCH_PROBE_TIMEOUT:-5}
max_misses=${MARCHYO_COMPOSITOR_WATCH_MISSES:-3}
max_gap=${MARCHYO_COMPOSITOR_WATCH_MAX_GAP:-30}
grace=${MARCHYO_COMPOSITOR_WATCH_GRACE:-10}
comm_glob=${MARCHYO_COMPOSITOR_WATCH_COMM:-*[Hh]yprland*}

hypr_root=${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/marchyo/hyprland

instance=
hypr_pid=

alive() {
  local stat
  [[ -r /proc/$1/stat ]] || return 1
  stat=$(<"/proc/$1/stat") || return 1
  [[ ${stat##*) } != Z* ]]
}

# The instance is the directory under $XDG_RUNTIME_DIR/hypr that holds the
# sockets; its hyprland.lock names the compositor's PID on the first line.
find_instance() {
  local lock pid best=
  instance=
  hypr_pid=
  for lock in "$hypr_root"/*/hyprland.lock; do
    [[ -r $lock ]] || continue
    pid=$(head -n 1 "$lock")
    [[ $pid =~ ^[0-9]+$ ]] || continue
    alive "$pid" || continue
    # shellcheck disable=SC2053
    [[ $(<"/proc/$pid/comm") == $comm_glob ]] || continue
    if [[ -z $best || $lock -nt $best ]]; then
      best=$lock
      hypr_pid=$pid
    fi
  done
  [[ -n $best ]] || return 1
  instance=${best%/hyprland.lock}
  instance=${instance##*/}
}

probe() {
  HYPRLAND_INSTANCE_SIGNATURE=$instance \
    timeout -k 2 "$probe_timeout" hyprctl -j version >/dev/null 2>&1
}

capture() {
  local pid=$1 dir task
  printf -v dir '%s/hang-%(%Y%m%dT%H%M%S)T' "$state_dir" -1
  mkdir -p "$dir" || return 1
  cp "$hypr_root/$instance/hyprland.log" "$dir/hyprland.log" 2>/dev/null
  cp "/proc/$pid/status" "$dir/status" 2>/dev/null
  for task in "/proc/$pid"/task/*; do
    printf '%s ' "${task##*/}"
    cat "$task/stat" 2>/dev/null || echo
  done >"$dir/threads" 2>/dev/null
  chrt -p "$pid" >"$dir/sched" 2>&1
  echo "marchyo-compositor-watch: Hyprland $pid hung, evidence in $dir" >&2
}

# SIGABRT lets systemd-coredump take a core; SIGKILL follows when the process
# is still there after the grace period.
rescue() {
  local pid=$hypr_pid waited=0
  capture "$pid"
  kill -ABRT "$pid" 2>/dev/null
  while alive "$pid" && ((waited < grace)); do
    sleep 1
    ((waited++))
  done
  if alive "$pid"; then
    kill -KILL "$pid" 2>/dev/null
  fi
}

watch() {
  local misses=0 now last=$EPOCHSECONDS
  while sleep "$interval"; do
    now=$EPOCHSECONDS
    # A gap this long means the machine was suspended: Hyprland needs a moment.
    if ((now - last > max_gap)); then
      misses=0
      last=$now
      continue
    fi
    last=$now
    if ! find_instance || probe; then
      misses=0
      continue
    fi
    ((++misses >= max_misses)) || continue
    rescue
    misses=0
    last=$EPOCHSECONDS
  done
}

case ${1:-} in
"") watch ;;
--now)
  if ! find_instance; then
    echo "marchyo-compositor-watch: no running Hyprland found" >&2
    exit 1
  fi
  rescue
  ;;
*)
  echo "usage: marchyo-compositor-watch [--now]" >&2
  exit 2
  ;;
esac
