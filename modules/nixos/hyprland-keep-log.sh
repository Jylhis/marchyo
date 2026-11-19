# shellcheck shell=bash
# Runs after the compositor stops: keeps its log, which lives on tmpfs, under
# the state directory and prunes all but the newest five.
set -uo pipefail

keep=5
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/marchyo/hyprland
newest=

for log in "${XDG_RUNTIME_DIR:-/run/user/$UID}"/hypr/*/hyprland.log; do
  [[ -f $log ]] || continue
  if [[ -z $newest || $log -nt $newest ]]; then
    newest=$log
  fi
done
[[ -n $newest ]] || exit 0

mkdir -p "$state_dir" || exit 0
printf -v name 'hyprland-%(%Y%m%dT%H%M%S)T.log' -1
cp "$newest" "$state_dir/$name"

logs=("$state_dir"/hyprland-*.log)
if ((${#logs[@]} > keep)); then
  rm -f -- "${logs[@]:0:${#logs[@]}-keep}"
fi
