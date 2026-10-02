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
GREETER_DIR="$ROOT/greeter"

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
for dir in "$SHELL_DIR"/*/ "$GREETER_DIR"/*/; do
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

# SystemClock is in the list because it was the one that slipped through: the
# clock widget owned a per-monitor SystemClock *and* a per-monitor format
# toggle, so the bars disagreed about the date format. It now reads
# Services/Clock.
stateful_widgets=$(grep -nE "^\s*(Process|Timer|Connections|FileView|Socket|SystemClock)\s*\{" "$SHELL_DIR"/Bar/*.qml 2>/dev/null)
check "no Bar/ widget owns a Process, Timer, Connections, FileView, Socket or SystemClock" "$stateful_widgets"

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

# ── Style.* generator parity ─────────────────────────────────────────────────
#
# Same failure mode one level up: Commons/Style.qml is the checked-in dev
# default and the Nix build replaces it with a generated file whose dimensions
# are scaled by fontScale. A property added to the checked-in file but not to
# the generator reads as undefined in the store shell only. The Config.* check
# above covered the tool paths; nothing covered the dimensions.
#
# Commons/Color.qml deliberately gets no equivalent check: its property names
# are computed in Nix from palette.hex via toCamel, so there is no literal name
# list in package.nix to grep against.

style_qml="$SHELL_DIR/Commons/Style.qml"
ungenerated_style=""
while read -r prop; do
  [[ -n $prop ]] || continue
  grep -qE "property (int|bool|real|string|color) $prop:" "$package_nix" ||
    ungenerated_style+="Style.$prop is declared in ${style_qml#"$ROOT"/} but not generated by ${package_nix#"$ROOT"/}"$'\n'
done < <(grep -oE "property (int|bool|real|string|color) [a-zA-Z]+:" "$style_qml" | awk '{print $3}' | tr -d ':' | sort -u)
check "every Commons/Style.qml property is also emitted by package.nix" "$ungenerated_style"

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

# One target, one handler: two handlers on the same target make which one
# answers a call undefined. Every Hyprland bind calls target "shell" (see
# plans/shell.md), so that name is shell.qml's alone, and shell.qml keeps a
# single stock handler rather than a bus. The compat shim's handlers are not
# competitors: compat/Commons/ShellIpc.qml is a base type with no target of its
# own, compat/Commons/IpcRegistry.qml holds a permanently disabled reflection
# probe, and compat/Ui/Panel.qml binds whatever target its omarchy plugin asks
# for. Only claiming the literal "shell" would collide.
ipc_handlers=$(grep -c "IpcHandler {" "$shell_qml")
if [[ $ipc_handlers == 1 ]]; then
  ok "shell.qml declares exactly one IpcHandler"
else
  no "shell.qml declares exactly one IpcHandler" "found $ipc_handlers"
fi

rival_shell_target=$(grep -rn --include="*.qml" 'target: *"shell"' "$SHELL_DIR" |
  grep -v "^$shell_qml:" | sed "s|^$ROOT/||")
check 'only shell.qml claims the IPC target "shell"' "$rival_shell_target"

# ── Commons/*.js dual citizenship ────────────────────────────────────────────
#
# tests/shell/{format,notify}-test.js load the Commons JavaScript modules as
# CommonJS. Lose the export guard and the suite fails loudly; add a `.pragma`
# directive (the natural QML idiom for a shared helper) and Node cannot parse
# the file at all. Both are pinned here so the reason survives next to the rule,
# and the loop covers every module so a new one cannot be added without them.

missing_exports=""
has_pragma=""
for js in "$SHELL_DIR"/Commons/*.js; do
  rel="${js#"$ROOT"/}"
  grep -q "module.exports" "$js" || missing_exports+="$rel has no CommonJS export guard"$'\n'
  grep -q "^\.pragma" "$js" && has_pragma+="$rel has a .pragma directive (Node cannot parse one)"$'\n'
done
check "every Commons/*.js keeps its CommonJS export guard" "$missing_exports"
check "no Commons/*.js has a .pragma directive (Node cannot parse one)" "$has_pragma"

# ── default bar layout ids resolve ───────────────────────────────────────────
#
# ShellConfig.defaultBar's ids resolve through shell.qml's barComponents map at
# RUNTIME (a miss loads nothing and silently shrinks the bar). Defaults are all
# first-party ids, so each must appear as a key in the barComponents map.

unresolved_ids=""
while read -r id; do
  [[ -n $id ]] || continue
  grep -q "\"$id\":" "$shell_qml" ||
    unresolved_ids+="$id is in ShellConfig.defaultBar but not in shell.qml barComponents"$'\n'
done < <(grep -oE 'id: "marchyo\.[a-zA-Z]+"' "$SHELL_DIR/Commons/ShellConfig.qml" | sed 's/id: "//;s/"//')
check "every default bar layout id resolves in shell.qml barComponents" "$unresolved_ids"

# ── separator id agrees across the layout data and the collapse logic ────────
#
# Commons/BarLayout.js decides which separators render by matching the literal
# entry id "marchyo.separator" (SEPARATOR_ID). ShellConfig's default layout and
# the Nix layout generator both spell that id too; a rename on one side only
# (layout data without the constant, or the constant without the data) leaves
# every rule permanently visible or permanently hidden at runtime.

sep_const="marchyo.separator"
sep_mismatches=""
grep -q "var SEPARATOR_ID = \"$sep_const\"" "$SHELL_DIR/Commons/BarLayout.js" ||
  sep_mismatches+="BarLayout.js SEPARATOR_ID is not \"$sep_const\""$'\n'
grep -q "id: \"$sep_const\"" "$SHELL_DIR/Commons/ShellConfig.qml" ||
  sep_mismatches+="ShellConfig.qml default layout no longer uses \"$sep_const\""$'\n'
check "the separator entry id matches BarLayout.SEPARATOR_ID everywhere" "$sep_mismatches"

echo "----"
echo "$pass passed, $fail failed"
[[ $fail == 0 ]]
