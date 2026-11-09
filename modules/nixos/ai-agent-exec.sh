# shellcheck shell=bash
# marchyo-agent-exec <claude|codex|grok> <real-binary> [args...]
#
# Starts an agent CLI as the active account of `marchyo agent account`. An
# explicit CLAUDE_CONFIG_DIR / CODEX_HOME / GROK_HOME wins. Otherwise the
# MARCHYO_AGENT_<P>_HOME pin (set by the first wrapper in a process tree,
# empty for the primary account) keeps subprocesses on the session's account.
# Without a pin the registry's active account is used; the primary account
# runs with no variable set, as the CLI expects.
set -u

provider=$1
real=$2
shift 2

case $provider in
claude) var=CLAUDE_CONFIG_DIR ;;
codex) var=CODEX_HOME ;;
grok) var=GROK_HOME ;;
*)
  echo "marchyo-agent-exec: unknown provider $provider" >&2
  exit 2
  ;;
esac
pin=MARCHYO_AGENT_${provider^^}_HOME

if [[ -z ${!var:-} ]]; then
  if [[ -v $pin ]]; then
    home=${!pin}
  else
    root=${XDG_STATE_HOME:-$HOME/.local/state}/marchyo/agents/accounts
    home=""
    if [[ -f $root/$provider.json ]]; then
      # Only a direct child of the provider's account directory is accepted.
      # shellcheck disable=SC2016 # $r and $dir are jq variables
      home=$(@jq@ -r --arg dir "$root/$provider/" '
        . as $r
        | [(.accounts // [])[]
            | select(type == "object" and .id == $r.active and .primary != true)
            | .home // ""
            | select(type == "string" and startswith($dir))
            | select(ltrimstr($dir) | test("^[a-z0-9]+(-[a-z0-9]+)*$"))]
        | first // ""' "$root/$provider.json" 2>/dev/null) || home=""
      [[ -n $home && -d $home ]] || home=""
    fi
    export "$pin=$home"
  fi
  if [[ -n $home ]]; then
    export "$var=$home"
  fi
fi

exec "$real" "$@"
