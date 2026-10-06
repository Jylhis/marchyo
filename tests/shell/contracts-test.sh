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
# The CLI verbs (`marchyo shell …`, `marchyo brightness`, `marchyo doctor`)
# call into the running shell by method name through core's shellIpc helper,
# always with a string-literal name. A renamed IpcHandler function leaves the
# verb, and every Hyprland bind on it, failing at runtime.

shell_qml="$SHELL_DIR/shell.qml"
cli_src="$ROOT/packages/marchyo-cli/packages"
cli_methods=$(grep -rhoE --include="*.ts" --include="*.tsx" 'shellIpc\("[a-zA-Z]+"' "$cli_src" |
  sed -E 's/.*"([a-zA-Z]+)"/\1/' | sort -u)
missing_ipc=""
[[ -n $cli_methods ]] || missing_ipc+="no shellIpc(\"<fn>\") call found under ${cli_src#"$ROOT"/}"$'\n'
while read -r method; do
  [[ -n $method ]] || continue
  grep -qE "^\s*function $method\(" "$shell_qml" ||
    missing_ipc+="the CLI calls shellIpc(\"$method\"), which shell.qml does not define"$'\n'
done <<<"$cli_methods"
check "every shellIpc method the CLI calls exists in shell.qml" "$missing_ipc"

# One target, one handler: two handlers on the same target make which one
# answers a call undefined. Every Hyprland bind calls target "shell" (see
# shell/README.md), so that name is shell.qml's alone, and shell.qml keeps a
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

# ── plugin index generator and kind wiring ───────────────────────────────────
#
# package.nix builds the store shell's Commons/PluginIndex.qml by replacing one
# marker line of the checked-in file with the baked plugin list, so both files
# share every function. If the marker drifts, the build aborts; this catches it
# without a build. Each PluginIndex function is one kind's consumer, so a
# function nothing calls is a kind the shell no longer loads.

plugin_index="$SHELL_DIR/Commons/PluginIndex.qml"
plugin_marker=$(grep -oE 'pluginIndexMarker = "[^"]+"' "$package_nix" | sed 's/^pluginIndexMarker = "//;s/"$//')
plugin_index_drift=""
if [[ -z $plugin_marker ]]; then
  plugin_index_drift="${package_nix#"$ROOT"/} defines no pluginIndexMarker"
else
  marker_lines=$(grep -cF -- "$plugin_marker" "$plugin_index")
  [[ $marker_lines == 1 ]] ||
    plugin_index_drift="${plugin_index#"$ROOT"/} has $marker_lines lines matching package.nix's marker '$plugin_marker' (want 1)"
fi
check "package.nix's PluginIndex marker appears exactly once in Commons/PluginIndex.qml" "$plugin_index_drift"

unused_index_fns=""
while read -r fn; do
  [[ -n $fn ]] || continue
  grep -rqE --include='*.qml' "PluginIndex\.$fn\(" "$SHELL_DIR" ||
    unused_index_fns+="PluginIndex.$fn() is called nowhere in shell/"$'\n'
done < <(grep -oE '^    function [a-zA-Z]+' "$plugin_index" | awk '{print $2}')
check "every public PluginIndex function has a caller in shell/" "$unused_index_fns"

# plugin.nix rejects launcher prefixes starting with a first-party prefix's
# first character; the two lists must agree.
plugin_nix="$ROOT/packages/marchyo-shell/plugin.nix"
reserved_starts=$(awk '/reservedPrefixStarts = \[/{f=1;next} f&&/\]/{f=0} f' "$plugin_nix" | grep -oE '"[^"]+"' | tr -d '"' | sort -u)
first_party_starts=$(grep -oE 'prefix: "[^"]+"' "$SHELL_DIR/Commons/LauncherProviders.js" | sed 's/^prefix: "//;s/"$//' | cut -c1 | sort -u)
prefix_drift=""
[[ $reserved_starts == "$first_party_starts" ]] ||
  prefix_drift="plugin.nix reservedPrefixStarts ($(tr '\n' ' ' <<<"$reserved_starts")) != LauncherProviders.js PREFIXES first characters ($(tr '\n' ' ' <<<"$first_party_starts"))"
check "plugin.nix reserves exactly the first-party launcher prefix characters" "$prefix_drift"

# The CLI validates manifests at `marchyo plugin add` with the same kind set and
# reserved prefix characters as plugin.nix.
plugins_ts="$ROOT/packages/marchyo-cli/packages/core/src/plugins.ts"
nix_kinds=$(grep -E '^[[:space:]]*"?[a-z-]+"?[[:space:]]*=[[:space:]]*"[A-Za-z]+";' \
  "$ROOT/packages/marchyo-shell/plugin-kinds.nix" | tr -d ' ";' | sort)
ts_kinds=$(sed -n '/^export const PLUGIN_KINDS = {/,/^} as const;/p' "$plugins_ts" |
  grep -E '^[[:space:]]*"?[a-z-]+"?:[[:space:]]*"[A-Za-z]+",?$' | tr -d ' ",' | tr ':' '=' | sort)
kind_drift=""
[[ -n $nix_kinds && $nix_kinds == "$ts_kinds" ]] ||
  kind_drift="plugin-kinds.nix ($(tr '\n' ' ' <<<"$nix_kinds")) != PLUGIN_KINDS ($(tr '\n' ' ' <<<"$ts_kinds"))"
check "plugin kinds match between plugin-kinds.nix and the CLI's PLUGIN_KINDS" "$kind_drift"

ts_starts=$(grep -E '^export const RESERVED_PREFIX_STARTS = ' "$plugins_ts" | grep -oE '"[^"]+"' | tr -d '"' | sort -u)
cli_prefix_drift=""
[[ -n $ts_starts && $reserved_starts == "$ts_starts" ]] ||
  cli_prefix_drift="plugin.nix reservedPrefixStarts ($(tr '\n' ' ' <<<"$reserved_starts")) != RESERVED_PREFIX_STARTS ($(tr '\n' ' ' <<<"$ts_starts"))"
check "reserved launcher prefix characters match between plugin.nix and the CLI" "$cli_prefix_drift"

echo "----"
echo "$pass passed, $fail failed"
[[ $fail == 0 ]]
