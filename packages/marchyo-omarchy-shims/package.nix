# The `omarchy-*` commands that imported omarchy plugins call by bare name,
# implemented on marchyo. The shell wrapper (packages/marchyo-shell/package.nix)
# prefixes this package's bin/ to its PATH only when plugins are declared or the
# dev loader is on. Shims that reach marchyo call `marchyo` from the session
# PATH and stop with one line when it is missing.
{
  lib,
  symlinkJoin,
  writeShellApplication,
  quickshell,
  jq,
  coreutils,
  util-linux,
  gnused,
}:
let
  shim =
    name: text: extraInputs:
    writeShellApplication {
      inherit name text;
      runtimeInputs = extraInputs;
      # The shims forward arguments verbatim; shellcheck's quoting rules hold.
    };

  needMarchyo = ''
    command -v marchyo >/dev/null 2>&1 || {
      echo "$0: the marchyo command is not on PATH" >&2
      exit 127
    }
  '';

  # `omarchy-shell <target> <method> [args]` -> the running shell's IPC.
  # `shell summon|hide|toggle|call <id> ...` go to the plugin host; an id the
  # host does not know falls back to the plugin's own IPC target, which is how
  # compat bar-widget panels register (compat/Ui/Panel.qml).
  omarchyShell = shim "omarchy-shell" ''
    # shellcheck disable=SC2154  # MARCHYO_SHELL_ROOT is set by the shell wrapper
    : "''${MARCHYO_SHELL_ROOT:?omarchy-shell: run it from the marchyo shell}"
    quiet=0
    if [ "''${1:-}" = "-q" ]; then
      quiet=1
      shift
    fi
    target="''${1:-}"
    method="''${2:-}"
    if [ "$#" -ge 2 ]; then shift 2; else shift "$#"; fi

    ipc() {
      quickshell -p "$MARCHYO_SHELL_ROOT" ipc -n call -- "$@"
    }

    run() {
      if [ "$quiet" = 1 ]; then
        ipc "$@" >/dev/null 2>&1 || exit 0
      else
        ipc "$@"
      fi
    }

    if [ "$target" = "shell" ]; then
      case "$method" in
        summon | hide | toggle)
          id="''${1:-}"
          payload="''${2:-}"
          [ -n "$payload" ] || payload='{}'
          fn="''${method}Plugin"
          if [ "$method" = "hide" ]; then
            reply="$(ipc shell "$fn" "$id" 2>/dev/null || true)"
          else
            reply="$(ipc shell "$fn" "$id" "$payload" 2>/dev/null || true)"
          fi
          if [ "$reply" != "unknown" ] && [ -n "$reply" ]; then
            [ "$quiet" = 1 ] || echo "$reply"
            exit 0
          fi
          [ "$method" = "summon" ] && method="show"
          run "$id" "$method"
          exit 0
          ;;
        call)
          run shell callPlugin "''${1:-}" "''${2:-}" "''${3:-}"
          exit 0
          ;;
      esac
    fi
    run "$target" "$method" "$@"
  '' [ quickshell ];

  # Persist a plugin's inline setting into marchyo's runtime overlay, which
  # Commons/ShellConfig reads as pluginSettings.
  omarchyBar =
    shim "omarchy-bar"
      ''
        if [ "''${1:-}" != "set" ]; then
          echo "omarchy-bar: only 'set' is supported" >&2
          exit 2
        fi
        shift
        id="''${1:?id}"
        key="''${2:?key}"
        value="''${3:?value}"
        json=0
        if [ "''${4:-}" = "--json" ]; then json=1; fi
        state="''${XDG_STATE_HOME:-$HOME/.local/state}/marchyo/shell"
        file="$state/plugin-settings.json"
        mkdir -p "$state"
        # Several `set` calls race on one file (a plugin saves each key in its
        # own process); serialise the read-modify-write.
        exec 9>"$state/.plugin-settings.lock"
        flock 9
        [ -f "$file" ] || echo '{}' > "$file"
        tmp="$(mktemp "$state/.plugin-settings.XXXXXX")"
        if [ "$json" = 1 ]; then
          jq --arg id "$id" --arg key "$key" --argjson val "$value" \
            '.[$id] = ((.[$id] // {}) + {($key): $val})' "$file" > "$tmp"
        else
          jq --arg id "$id" --arg key "$key" --arg val "$value" \
            '.[$id] = ((.[$id] // {}) + {($key): $val})' "$file" > "$tmp"
        fi
        mv -f "$tmp" "$file"
      ''
      [
        jq
        coreutils
        util-linux
      ];

  # The flags are omarchy-notification-send's, which `marchyo notify` mirrors:
  # --app-name, -g/--glyph, -u/--urgency, -i/--icon, -t/--expire-time,
  # -r/--replace-id, -p/--print-id, --transient, --image, then the headline,
  # an optional description, and --exec or up to three --action groups.
  omarchyNotificationSend = shim "omarchy-notification-send" ''
    ${needMarchyo}
    exec marchyo notify "$@"
  '' [ ];

  # omarchy-menu-select <prompt> [option...] [-- menu args...]: options come as
  # arguments or on stdin; the menu args are --multiple, --selected <v>,
  # --on-change <json>, --change-key <k>, --width <px>, --maxheight <px>.
  omarchyMenuSelect = shim "omarchy-menu-select" ''
    ${needMarchyo}
    if [ "$#" -lt 1 ]; then
      echo "Usage: omarchy-menu-select <prompt> [option...] [-- menu args...]" >&2
      exit 1
    fi
    prompt="$1"
    shift
    options=()
    while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
      options+=("$1")
      shift
    done
    [ "$#" -gt 0 ] && shift
    menu_args=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --height) menu_args+=(--maxheight "''${2:?--height needs a value}"); shift 2 ;;
        --multiple) menu_args+=(--multiple); shift ;;
        --selected | --on-change | --change-key | --width | --maxheight)
          menu_args+=("$1" "''${2:?$1 needs a value}")
          shift 2
          ;;
        *) shift ;;
      esac
    done
    if [ "''${#options[@]}" -gt 0 ]; then
      printf '%s\n' "''${options[@]}" | marchyo menu select --prompt "$prompt" "''${menu_args[@]}"
    else
      marchyo menu select --prompt "$prompt" "''${menu_args[@]}"
    fi
  '' [ ];

  omarchyMenuInput = shim "omarchy-menu-input" ''
    ${needMarchyo}
    prompt="''${1:-Input}"
    [ "$#" -gt 0 ] && shift
    width=()
    while [ "$#" -gt 0 ]; do
      if [ "$1" = "--width" ]; then
        width=(--width "''${2:?--width needs a value}")
        shift
      fi
      shift
    done
    exec marchyo menu input --prompt "$prompt" "''${width[@]}"
  '' [ ];

  omarchyLaunchBrowser = shim "omarchy-launch-browser" ''
    ${needMarchyo}
    args=()
    for a in "$@"; do
      [ "$a" = "--private" ] || args+=("$a")
    done
    exec marchyo launch browser "''${args[@]}"
  '' [ ];

  omarchyLaunchTerminal = shim "omarchy-launch-terminal" ''
    ${needMarchyo}
    case "''${1:-}" in --pid=*) shift ;; esac
    exec marchyo launch terminal "$@"
  '' [ ];

  omarchyLaunchFloatingTerminal = shim "omarchy-launch-floating-terminal-with-presentation" ''
    ${needMarchyo}
    exec marchyo launch floating-terminal "$@"
  '' [ ];

  # The default agent is the declarative marchyo.ai choice ($AI_AGENT); it is
  # not changed from here.
  omarchyDefaultAgent = shim "omarchy-default-agent" ''
    if [ "$#" -eq 0 ]; then
      if [ -n "''${AI_AGENT:-}" ]; then basename "$AI_AGENT"; fi
      exit 0
    fi
    echo "omarchy-default-agent: the default agent is set declaratively (marchyo.ai)" >&2
    exit 1
  '' [ coreutils ];

  omarchyCmdPresent = shim "omarchy-cmd-present" ''
    for cmd in "$@"; do
      command -v -- "$cmd" >/dev/null 2>&1 || exit 1
    done
    exit 0
  '' [ ];

  # A package counts as installed when a profile or the system carries a store
  # path or a binary with that name.
  omarchyPkgPresent = shim "omarchy-pkg-present" ''
    closure=""
    for pkg in "$@"; do
      case "$pkg" in
        "" | */*) exit 1 ;;
      esac
      found=1
      for root in "$HOME/.nix-profile" "/etc/profiles/per-user/''${USER:-}" /run/current-system/sw; do
        if [ -e "$root/bin/$pkg" ]; then found=0; break; fi
      done
      if [ "$found" = 1 ]; then
        # Read the closure whole: `grep -q` closing the pipe early would hand
        # nix-store a SIGPIPE, which pipefail turns into "missing".
        if [ -z "$closure" ]; then
          closure=$(nix-store --query --requisites /run/current-system 2>/dev/null) || exit 1
        fi
        grep -qF -- "-$pkg-" <<<"$closure" || exit 1
      fi
    done
    exit 0
  '' [ ];
  omarchyLaunchEditor = shim "omarchy-launch-editor" ''
    ${needMarchyo}
    inline=0
    if [ "''${1:-}" = "--inline" ]; then
      inline=1
      shift
    fi
    editor="''${VISUAL:-''${EDITOR:-nvim}}"
    if [ "$inline" = 1 ]; then
      exec "$editor" -- "$@"
    fi
    exec marchyo launch terminal "$editor" -- "$@"
  '' [ ];

  # omasnap opens an image for annotation; with no file it takes a screenshot.
  omasnap = shim "omasnap" ''
    ${needMarchyo}
    path=""
    for a in "$@"; do
      case "$a" in
        --notify | --copy | --save) ;;
        *) path="$a" ;;
      esac
    done
    if [ -z "$path" ]; then
      exec marchyo capture screenshot
    fi
    if command -v satty >/dev/null 2>&1; then
      exec satty --filename "$path"
    fi
    exec xdg-open "$path"
  '' [ ];

  omarchyFontList = shim "omarchy-font-list" ''
    ${needMarchyo}
    exec marchyo font list
  '' [ ];

  omarchyFontCurrent = shim "omarchy-font-current" ''
    ${needMarchyo}
    exec marchyo font current
  '' [ ];

  omarchyFontSet = shim "omarchy-font-set" ''
    ${needMarchyo}
    exec marchyo font set "''${1:?omarchy-font-set: family needed}"
  '' [ ];

  # `marchyo powerprofile list` prints powerprofilesctl's block list; the menu
  # provider wants one profile name per line.
  omarchyPowerprofilesList = shim "omarchy-powerprofiles-list" ''
    ${needMarchyo}
    marchyo powerprofile list | sed -n -E 's/^[* ] ([a-z-]+):$/\1/p'
  '' [ gnused ];

  omarchyPowerprofilesSet = shim "omarchy-powerprofiles-set" ''
    ${needMarchyo}
    [ "''${1:-}" = "autodetect" ] && shift
    exec marchyo powerprofile set "''${1:?omarchy-powerprofiles-set: profile needed}"
  '' [ ];

  # No argument prints the current code; `list` prints "name<TAB>code<TAB>english"
  # rows; a code switches the display language.
  omarchyLanguage = shim "omarchy-language" ''
    ${needMarchyo}
    case "''${1:-}" in
      "") marchyo language --json | jq -r '.language.code' ;;
      list)
        marchyo language list --json \
          | jq -r '.languages[] | [.name, .code, .englishName] | @tsv'
        ;;
      *) exec marchyo language "$1" ;;
    esac
  '' [ jq ];
in
symlinkJoin {
  name = "marchyo-omarchy-shims";
  paths = [
    omarchyShell
    omarchyBar
    omarchyNotificationSend
    omarchyMenuSelect
    omarchyMenuInput
    omarchyLaunchBrowser
    omarchyLaunchTerminal
    omarchyLaunchFloatingTerminal
    omarchyDefaultAgent
    omarchyCmdPresent
    omarchyPkgPresent
    omarchyLaunchEditor
    omasnap
    omarchyFontList
    omarchyFontCurrent
    omarchyFontSet
    omarchyPowerprofilesList
    omarchyPowerprofilesSet
    omarchyLanguage
  ];
  meta = {
    description = "omarchy-* command shims for imported omarchy shell plugins";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
