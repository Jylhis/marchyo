#!/usr/bin/env bash
# Load the built shell tree headlessly: run harness.qml under quickshell with
# the offscreen Qt platform and fail on a QML load or binding error.
#
# Usage: load-test.sh QUICKSHELL QML_PATH [--long-running]
#
# QML_PATH is harness.qml, which quits itself, or with --long-running a config
# directory (the greeter) that runs until the timeout kills it.
#
# A truncated or mistyped QML file passes the static checks; only a real load
# resolves types and bindings. PanelWindow surfaces need a layer-shell
# compositor, so the harness instantiates the rest of the tree (see harness.qml).

set -euo pipefail

quickshell=${1:?usage: load-test.sh QUICKSHELL SHELL_DIR}
target=${2:?usage: load-test.sh QUICKSHELL QML_PATH [--long-running]}
long_running=${3:-}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/home" "$work/run"
chmod 700 "$work/run"
log=$work/log

status=0
env -i PATH="$PATH" HOME="$work/home" XDG_RUNTIME_DIR="$work/run" \
  TZDIR=/etc/zoneinfo QT_QPA_PLATFORM=offscreen \
  OMARCHY_PATH="$(dirname "$target")/compat/omarchy" \
  timeout "$([ -n "$long_running" ] && echo 15 || echo 60)" "$quickshell" -p "$target" >"$log" 2>&1 || status=$?
sed -i 's/\x1b\[[0-9;]*m//g' "$log"

# Environment noise of a sandbox with no compositor, bus or audio server.
noise=(
  'HYPRLAND_INSTANCE_SIGNATURE is unset'
  'quickshell.service.pipewire.loop: Failed to connect pipewire context'
  'quickshell.service.mpris.watcher: Could not connect to DBus'
  'quickshell.service.sni.watcher: Could not connect to DBus'
  'quickshell.service.sni.host: Could not connect to DBus'
  'Detected locale "C"'
  'This plugin does not support setting window masks'
  # Quickshell logs this once for the dev IpcHandler's settleReached signal; the signal works.
  'IpcHandler at @Services/Dev.qml.*Signal detected: "settleReached"'
)
noise_re=$(printf '%s|' "${noise[@]}")
noise_re=${noise_re%|}

fail=0
[ -n "$long_running" ] && [ "$status" -eq 124 ] && status=0
if [ "$status" -ne 0 ]; then
  echo "FAIL: quickshell exited with status $status" >&2
  fail=1
fi
grep -q 'Configuration Loaded' "$log" || {
  echo "FAIL: never reached 'Configuration Loaded'" >&2
  fail=1
}
if [ -z "$long_running" ]; then
  grep -q 'ASSERT-DONE' "$log" || {
    echo "FAIL: harness assertions never ran" >&2
    fail=1
  }
fi

patterns='Failed to load configuration|is not a type|ReferenceError|TypeError|Cannot assign|Unable to assign|ASSERT-FAIL'
tree='qml\[|/shell/|@[A-Za-z/]+\.qml'
bad=$(grep -E "$patterns|^ *(WARN|ERROR).*($tree)" "$log" | grep -Ev "$noise_re" || true)
if [ -n "$bad" ]; then
  echo "FAIL: QML errors while loading the shell:" >&2
  echo "$bad" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "--- full log ---" >&2
  cat "$log" >&2
  exit 1
fi
echo "load-test: shell tree loaded and bound cleanly"
