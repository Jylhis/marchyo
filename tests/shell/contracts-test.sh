#!/usr/bin/env bash
# Static contracts for the Quickshell tree in shell/.
#
# QML resolves its imports, its qmldir entries and its IpcHandler methods at
# RUNTIME, so a rename on one side of any agreement below shows up as a broken
# bar on a user's desktop rather than as a failed build. `just -f shell/Justfile
# check` would catch some of it, but it needs Quickshell and a Qt platform
# plugin, so `nix flake check` cannot run it. These greps are what remains
# checkable without a compositor — pinning the agreements a refactor could
# silently break, in the same spirit as tests/eval/*.nix for the Nix modules.
#
# Run: bash tests/shell/contracts-test.sh   (also a `nix flake check` check)

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
SHELL_DIR="$ROOT/shell"

pass=0
fail=0

ok() {
  echo "ok - $1"
  pass=$((pass + 1))
}

no() {
  echo "not ok - $1" >&2
  [[ -n ${2:-} ]] && printf '%s\n' "$2" | sed 's/^/    /' >&2
  fail=$((fail + 1))
}

check() { # check NAME DETAIL_IF_NONEMPTY
  if [[ -z $2 ]]; then ok "$1"; else no "$1" "$2"; fi
}

# ── qmldir completeness ──────────────────────────────────────────────────────
#
# A .qml file that is not listed in its directory's qmldir is invisible to
# `import qs.<Module>`, and a qmldir line pointing at a missing file breaks the
# whole module. Both fail only when the shell starts.

missing_from_qmldir=""
missing_files=""
for dir in "$SHELL_DIR"/*/; do
  qmldir="$dir/qmldir"
  [[ -f $qmldir ]] || continue
  for qml in "$dir"*.qml; do
    [[ -f $qml ]] || continue
    base=$(basename -- "$qml")
    grep -qE "(^| )$base\$" "$qmldir" ||
      missing_from_qmldir+="${dir#"$ROOT"/}$base is not declared in ${qmldir#"$ROOT"/}"$'\n'
  done
  while read -r declared; do
    [[ -n $declared ]] || continue
    [[ -f $dir$declared ]] ||
      missing_files+="${qmldir#"$ROOT"/} declares $declared, which does not exist"$'\n'
  done < <(awk '$NF ~ /\.qml$/ { print $NF }' "$qmldir")
done
check "every .qml in a module directory is declared in its qmldir" "$missing_from_qmldir"
check "every qmldir entry points at a file that exists" "$missing_files"

# ── bar widgets stay pure views ──────────────────────────────────────────────
#
# shell.qml builds the bar once per screen (`Variants { model: Quickshell
# .screens }`), so anything stateful inside a Bar/ widget is duplicated per
# monitor: a Process becomes one subprocess per screen, a repeating Timer one
# poll per screen, a Connections one handler per screen — all answering the same
# seat-global question. Bar/ widgets bind to Services/ singletons and own no
# runtime state of their own; this is the guard on that.

stateful_widgets=$(grep -nE "^\s*(Process|Timer|Connections|FileView|Socket)\s*\{" "$SHELL_DIR"/Bar/*.qml 2>/dev/null)
check "no Bar/ widget owns a Process, Timer, Connections, FileView or Socket" "$stateful_widgets"

# Seat-global singletons must actually be singletons, or the per-monitor
# duplication comes back through the other door.
not_singletons=""
for service in "$SHELL_DIR"/Services/*.qml; do
  head -1 "$service" | grep -q "^pragma Singleton\$" ||
    not_singletons+="$(basename -- "$service") does not start with 'pragma Singleton'"$'\n'
done
check "every Services/ component is a singleton" "$not_singletons"

# ── external tool paths ──────────────────────────────────────────────────────
#
# Commons/Config.qml is the checked-in dev default (bare PATH names); the Nix
# build overwrites it with absolute /nix/store paths from callPackage args. A
# Config.<tool> the generated file does not set reads as undefined in the store
# shell, and the widget spawns a command with an empty argv[0] — a failure that
# only ever appears on a real host, never in the dev tree.

config_qml="$SHELL_DIR/Commons/Config.qml"
package_nix="$ROOT/packages/marchyo-shell/package.nix"
undeclared_tools=""
unbaked_tools=""
while read -r tool; do
  [[ -n $tool ]] || continue
  grep -qE "property string $tool:" "$config_qml" ||
    undeclared_tools+="Config.$tool is used but not declared in ${config_qml#"$ROOT"/}"$'\n'
  grep -qE "property string $tool: \"\\\$\{" "$package_nix" ||
    unbaked_tools+="Config.$tool is used but not baked by ${package_nix#"$ROOT"/}"$'\n'
done < <(grep -rhoE "\bConfig\.[a-zA-Z]+" "$SHELL_DIR" | cut -d. -f2 | sort -u | grep -v '^qml$')
check "every Config.<tool> the QML uses is declared in Commons/Config.qml" "$undeclared_tools"
check "every Config.<tool> the QML uses gets a store path from package.nix" "$unbaked_tools"

# ── IPC contract ─────────────────────────────────────────────────────────────
#
# The Hyprland keybinds call into the running shell by method name. A renamed
# IpcHandler function leaves the keybind silently doing nothing.

shell_qml="$SHELL_DIR/shell.qml"
missing_ipc=""
while read -r method; do
  [[ -n $method ]] || continue
  grep -qE "^\s*function $method\(" "$shell_qml" ||
    missing_ipc+="modules/home calls 'shell $method', which shell.qml does not define"$'\n'
done < <(grep -rhoE "ipc -n call -- shell [a-zA-Z]+" "$ROOT/modules/home" | awk '{ print $NF }' | sort -u)
check "every IPC method the Hyprland binds call exists in shell.qml" "$missing_ipc"

# One target, one handler: two IpcHandlers on the same target make which one
# answers a call undefined (see plans/shell.md — there is deliberately no bus).
ipc_handlers=$(grep -c "IpcHandler {" "$shell_qml")
extra_handlers=$(grep -rl --include="*.qml" "IpcHandler {" "$SHELL_DIR" | grep -v "/shell\.qml$")
if [[ $ipc_handlers == 1 && -z $extra_handlers ]]; then
  ok "shell.qml declares the tree's only IpcHandler"
else
  no "shell.qml declares the tree's only IpcHandler" "found $ipc_handlers in shell.qml; also in: ${extra_handlers:-none}"
fi

# ── Format.js dual citizenship ───────────────────────────────────────────────
#
# tests/shell/format-test.js loads Commons/Format.js as a CommonJS module. Lose
# the export guard and the suite fails loudly; add a `.pragma` directive (the
# natural QML idiom for a shared helper) and Node cannot parse the file at all.
# Both are pinned here so the reason survives next to the rule.

format_js="$SHELL_DIR/Commons/Format.js"
if grep -q "module.exports" "$format_js"; then
  ok "Commons/Format.js keeps its CommonJS export guard"
else
  no "Commons/Format.js keeps its CommonJS export guard"
fi
if grep -q "^\.pragma" "$format_js"; then
  no "Commons/Format.js has no .pragma directive (Node cannot parse one)"
else
  ok "Commons/Format.js has no .pragma directive (Node cannot parse one)"
fi

echo "----"
echo "$pass passed, $fail failed"
[[ $fail == 0 ]]
