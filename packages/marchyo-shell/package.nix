{
  lib,
  stdenvNoCC,
  quickshell,
  makeWrapper,
  writeText,
  writeShellApplication,
  gawk,
  jylhis-design-src,
  # External tools the interactive widgets shell out to. Baked into a generated
  # Commons/Config.qml as absolute /nix/store paths so the store shell never
  # relies on the session PATH. Same packages/commands waybar.nix wires.
  ghostty,
  hyprland,
  voxtype,
  wiremix,
  btop,
  networkmanager,
  bluetui,
  procps,
  coreutils,
  wtype,
  cliphist,
  wl-clipboard,
  unicode-emoji,
  marchyo-cli,
  solaar,
  tailscale,
  curl,
  qrencode,
  libqalculate,
  findutils,
  uwsm,
  systemd,
  # Runtime tools the omarchy plugin compat shim puts on the shell's PATH, but
  # only when plugins are declared (see the wrapper below). omarchy plugins call
  # these by bare name: python3 (agent-activity's odv.py collector), notify-send
  # (SBB delay alerts), jq (omarchy-bar's settings encode). curl / hyprland /
  # coreutils are already inputs.
  python3,
  libnotify,
  jq,
  # "dark" = Jylhis Dark, "light" = Jylhis Light — matches marchyo.theme.variant.
  variant ? "dark",
  # marchyo.theme.fontScale — every bar dimension derives from it via
  # lib/font-scale.nix, so the shell scales with the rest of the desktop.
  fontScale ? 1.0,
  # marchyo.dictation.{enable,indicator} — bakes the dictation bar widget in/out
  # (the shell reads no runtime config yet; parity with waybar's voxtypeIndicator).
  dictationIndicator ? false,
  # marchyo.menus.enable — drives the power panel's menu button (marchyo menu
  # power vs the in-shell app launcher), matching waybar's menusEnabled gate.
  menusEnabled ? true,
  # marchyo.hardware.logitech.enable — arms the solaar HID++ fallback in the
  # peripherals-battery service (only useful with a Logi receiver the kernel
  # will not bind); off by default so no solaar poll runs.
  peripheralsFallback ? false,
  # marchyo.services.tailscale.enable — conditionally bakes the tailscale CLI
  # path into Config so the store shell can drive the Tailscale status widget.
  # When off, the bare name is baked (never forced into the closure) and the
  # widget self-hides because the command is absent. Keeps tailscale out of the
  # shell closure on hosts that do not use it.
  tailscaleEnabled ? false,
  # marchyo.notifications.rules — per-sender notification rules, baked as a QML
  # array literal (JSON is valid JS). Empty by default. See Services/Notification
  # State.qml for the match/apply logic.
  notifRules ? [ ],
  # marchyo.theme.appearance.* — palette-independent scale axes (Caelestia's
  # split). Neutral defaults reproduce the current look.
  cornerRadiusScale ? 1.0,
  uiScale ? 1.0,
  animationSpeed ? 1.0,
  highContrast ? false,
  # marchyo.theme.appearance.floatingBar / surfaceAlpha — the Caelestia-inspired
  # style axes: a detached rounded pill bar instead of the full-width strip, and
  # translucent glass surfaces (alpha < 1 pairs with the Hyprland blur layer
  # rules modules/home/hyprland.nix registers for the shell's namespaces).
  floatingBar ? true,
  surfaceAlpha ? 0.85,
  # Shell plugins (build-time Option A). A list of pkgs.mkMarchyoShellPlugin
  # derivations; each carries passthru.marchyoPlugin = { id; kinds; entryPoints;
  # prefix; source; ... }. When non-empty, each plugin dir is copied under
  # share/marchyo/shell/plugins/ and Commons/PluginIndex.qml is regenerated to
  # list them. Empty by default, so the dev tree and plugin-less hosts keep the
  # checked-in empty index. share/marchyo/shell/plugins.lock.json lists them in
  # every build.
  plugins ? [ ],
}:
let
  # Reuse the design-system palette helper (single source of truth for token ->
  # hex resolution and the palette/status/syntax merge) rather than re-reading
  # theme file here. It only touches pkgs.jylhis-design-src, so a one-attr stub
  # is enough in this callPackage context. Same idiom as modules/home/vicinae.nix.
  palette = import ../../modules/generic/jylhis-palette.nix {
    pkgs = { inherit jylhis-design-src; };
    inherit lib variant;
  };
  fs = import ../../lib/font-scale.nix {
    inherit lib;
    scale = fontScale;
  };
  # Geometry (non-font) dimensions scale by fontScale AND uiScale, so uiScale is
  # a size axis independent of text size. Fonts keep using `fs` (fontScale only).
  ui = import ../../lib/font-scale.nix {
    inherit lib;
    scale = fontScale * uiScale;
  };
  # Corner radii additionally scale by cornerRadiusScale (0 = square corners).
  radiusPx = base: builtins.floor (base * fontScale * uiScale * cornerRadiusScale + 0.5);
  # Base animation duration (ms) divided by the speed multiplier.
  animMs = base: builtins.floor (base / animationSpeed + 0.5);

  # Commons/Theme.qml dev default embeds the dark (Jylhis Dark) fallback palette.
  # For a light-variant host, translate those literals to the host variant
  # with the same semantic-token hex swap modules/home/theme-runtime.nix uses
  # (accent == cursor agree in both variants, so the mapping is well-defined;
  # the file's only hexes are the fallback literals). This keeps a
  # theme-disabled light host from flashing/showing dark bar colors.
  darkPalette = import ../../modules/generic/jylhis-palette.nix {
    pkgs = { inherit jylhis-design-src; };
    inherit lib;
    variant = "dark";
  };
  tokenNameList = lib.attrNames darkPalette.hex;
  # The dev-default Theme.qml (whose only hexes are the Jylhis Dark fallback
  # literals) hex-swapped to the host variant — the same semantic-token swap
  # modules/home/theme-runtime.nix uses. Parameterized by source tree: the
  # shell's Theme.qml and the greeter's static Theme.qml both carry the same
  # literals, so both get the same treatment.
  themeQmlFor =
    devThemePath:
    writeText "Theme.qml" (
      let
        devTheme = builtins.readFile devThemePath;
      in
      if variant == "dark" then
        devTheme
      else
        builtins.replaceStrings (map (n: darkPalette.hex.${n}) tokenNameList) (map (
          n: palette.hex.${n}
        ) tokenNameList) devTheme
    );
  themeQml = themeQmlFor ../../shell/Commons/Theme.qml;
  greeterThemeQml = themeQmlFor ../../greeter/Commons/Theme.qml;

  # Bar colors: every palette + status token, minus syntax-highlighting tokens
  # (syn-*) which no UI surface uses.
  hex = lib.filterAttrs (n: _: !lib.hasPrefix "syn-" n) palette.hex;
  toCamel = import ../../lib/camel-case.nix { inherit lib; };
  colorLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: _: "readonly property color ${toCamel name}: Theme.palette.${toCamel name}"
    ) hex
  );

  # Generated color singleton, overwriting the checked-in dev default (which
  # carries the same delegation): every token binds Theme.palette.<camel> so
  # the whole bar live-recolors on `marchyo theme set`. Theme.qml below bakes
  # the host-variant fallback palette; this file is variant-independent.
  colorQml = builtins.toFile "Color.qml" ''
    pragma Singleton
    import QtQuick

    // Generated from the Jylhis design system theme. Every token
    // delegates to Theme.palette (Commons/Theme.qml) so the whole bar
    // live-recolors on `marchyo theme set`.
    QtObject {
    ${colorLines}
      // Back-compat aliases for the Phase 0 property names.
      readonly property color background: bg
      readonly property color foreground: text
    }
  '';

  # Generated dimension/config singleton: bar geometry and font sizes scaled by
  # marchyo.theme.fontScale, plus the baked-in feature flags the shell reads (no
  # runtime shell.json yet).
  styleQml = builtins.toFile "Style.qml" ''
    pragma Singleton
    import QtQuick

    // Generated from lib/font-scale.nix (scale ${toString fontScale}).
    QtObject {
      readonly property int barHeight: ${toString (ui.round 28)}
      readonly property int fontSize: ${toString (fs.round 14)}
      readonly property int fontSizeSmall: ${toString (fs.round 12)}
      readonly property int spacing: ${toString (ui.round 4)}
      readonly property int paddingH: ${toString (ui.round 6)}
      readonly property int barItemPad: ${toString (ui.round 4)}
      readonly property string fontFamily: "BlexMono Nerd Font"

      // Floating pill bar (marchyo.theme.appearance.floatingBar): gap from the
      // screen edges and the bar's corner radius. All bake to 0 in strip mode
      // (floatingBar false), where the bar spans edge to edge as before.
      readonly property bool barFloating: ${lib.boolToString floatingBar}
      readonly property int barMarginH: ${toString (if floatingBar then ui.round 6 else 0)}
      readonly property int barMarginV: ${toString (if floatingBar then ui.round 6 else 0)}
      readonly property int barRadius: ${toString (if floatingBar then radiusPx 12 else 0)}

      // Glass surfaces (marchyo.theme.appearance.surfaceAlpha): opacity applied
      // to every shell card; 1.0 restores the opaque flat look (and the home
      // Hyprland config keeps blur off).
      readonly property real surfaceAlpha: ${toString surfaceAlpha}

      // On-screen-display geometry (volume/brightness overlay).
      readonly property int osdPad: ${toString (ui.round 14)}
      readonly property int osdRadius: ${toString (radiusPx 8)}
      readonly property int osdMargin: ${toString (ui.round 80)}
      readonly property int osdBarWidth: ${toString (ui.round 140)}
      readonly property int osdBarHeight: ${toString (ui.round 6)}

      // Summonable-panel geometry (audio/network/power/monitor cards under the bar).
      readonly property int panelWidth: ${toString (ui.round 260)}
      readonly property int panelPad: ${toString (ui.round 14)}
      readonly property int panelGap: ${toString (ui.round 6)}
      readonly property int panelRadius: ${toString (radiusPx 8)}
      readonly property int panelRowHeight: ${toString (ui.round 30)}

      // Control Center geometry (wider card, quick-toggle tiles, slider track).
      readonly property int controlCenterWidth: ${toString (ui.round 340)}
      readonly property int tileHeight: ${toString (ui.round 52)}
      readonly property int sliderTrackHeight: ${toString (ui.round 6)}

      // Launcher geometry (apps/emoji/clipboard card).
      readonly property int launcherWidth: ${toString (ui.round 640)}

      // Media (MPRIS) widget: max characters of the track title shown in the bar.
      readonly property int mediaMaxChars: 40

      // Notification-toast geometry (replaces mako; mako uses width 380, pad 8,
      // radius 0 sharp corners, border 2, margin 10). Pixel sizes scale with the
      // font; the timeouts are milliseconds and stay unscaled.
      readonly property int notifWidth: ${toString (ui.round 380)}
      readonly property int notifPad: ${toString (ui.round 12)}
      readonly property int notifRadius: ${toString (radiusPx 0)}
      readonly property int notifBorder: ${toString (if highContrast then 3 else 2)}
      readonly property int notifGap: ${toString (ui.round 8)}
      readonly property int notifMargin: ${toString (ui.round 10)}
      readonly property int notifIconSize: ${toString (ui.round 40)}
      readonly property int notifMaxVisible: 5
      readonly property int notifTimeoutLow: 5000
      readonly property int notifTimeoutNormal: 5000
      readonly property int notifTimeoutCritical: 0
      readonly property int notifCenterMaxHeight: ${toString (ui.round 420)}
      readonly property var notifRules: ${builtins.toJSON notifRules}

      // Appearance scale axes (marchyo.theme.appearance).
      readonly property int animationDuration: ${toString (animMs 150)}
      readonly property bool highContrast: ${lib.boolToString highContrast}
      readonly property int borderWidth: ${toString (if highContrast then 2 else 1)}

      // Whether to run the solaar HID++ fallback for peripherals battery.
      readonly property bool peripheralsFallback: ${lib.boolToString peripheralsFallback}

      // Baked feature flags (parity with waybar's conditional widgets).
      readonly property bool dictationIndicator: ${lib.boolToString dictationIndicator}
      readonly property bool menusEnabled: ${lib.boolToString menusEnabled}
    }
  '';

  # Generated tool-path singleton: absolute /nix/store paths for the binaries the
  # interactive widgets launch or probe, overwriting the checked-in dev default so
  # the store shell never depends on the session PATH. Same commands as waybar.nix.
  # writeText (not builtins.toFile) because the content references store paths.
  configQml = writeText "Config.qml" ''
    pragma Singleton
    import QtQuick

    // Generated by packages/marchyo-shell/package.nix — resolved tool paths.
    QtObject {
      readonly property string terminal: "${lib.getExe ghostty}"
      readonly property string hyprctl: "${lib.getExe' hyprland "hyprctl"}"
      readonly property string voxtype: "${lib.getExe voxtype}"
      readonly property string wiremix: "${lib.getExe wiremix}"
      readonly property string btop: "${lib.getExe btop}"
      readonly property string nmtui: "${lib.getExe' networkmanager "nmtui"}"
      readonly property string nmcli: "${lib.getExe' networkmanager "nmcli"}"
      readonly property string bluetui: "${lib.getExe bluetui}"
      readonly property string pgrep: "${lib.getExe' procps "pgrep"}"
      readonly property string ls: "${lib.getExe' coreutils "ls"}"
      readonly property string df: "${lib.getExe' coreutils "df"}"
      readonly property string wtype: "${lib.getExe wtype}"
      readonly property string cliphist: "${lib.getExe cliphist}"
      readonly property string wlCopy: "${lib.getExe' wl-clipboard "wl-copy"}"
      readonly property string marchyo: "${lib.getExe marchyo-cli}"
      readonly property string solaar: "${lib.getExe solaar}"
      readonly property string systemctl: "${lib.getExe' systemd "systemctl"}"
      readonly property string tailscale: "${
        if tailscaleEnabled then lib.getExe tailscale else "tailscale"
      }"
      readonly property string curl: "${lib.getExe curl}"
      readonly property string qrencode: "${lib.getExe qrencode}"
      readonly property string qalc: "${lib.getExe libqalculate}"
      readonly property string find: "${lib.getExe' findutils "find"}"
      readonly property string ps: "${lib.getExe' procps "ps"}"
    }
  '';

  # Generated greeter tool-path singleton: the uwsm session argv for
  # Greetd.launch(), systemctl for the power buttons, and timeout/head for the
  # theme marker reader, all absolute so the greeter never depends on greetd's
  # daemon PATH.
  greeterConfigQml = writeText "Config.qml" ''
    pragma Singleton
    import QtQuick

    // Generated by packages/marchyo-shell/package.nix — greeter tool paths.
    QtObject {
      readonly property var sessionCommand: [ "${lib.getExe uwsm}", "start", "hyprland-uwsm.desktop" ]
      readonly property string systemctl: "${lib.getExe' systemd "systemctl"}"
      readonly property string timeout: "${lib.getExe' coreutils "timeout"}"
      readonly property string head: "${lib.getExe' coreutils "head"}"
    }
  '';

  # Plugin index (build-time Option A). Each plugin's entry points are rewritten
  # to a path relative to Commons/ (where PluginIndex.qml lives), so
  # Qt.createComponent resolves them against the copied-in plugins/ tree and the
  # loaded QML still sees the qs.* namespace of the shell config root.
  pluginsForQml = map (p: {
    inherit (p.marchyoPlugin)
      id
      name
      version
      kinds
      ;
    prefix = p.marchyoPlugin.prefix or null;
    entryPoints = lib.mapAttrs (
      _kind: ep: "../plugins/${p.marchyoPlugin.id}/${ep}"
    ) p.marchyoPlugin.entryPoints;
  }) plugins;

  # The generated index is the checked-in Commons/PluginIndex.qml with its one
  # `plugins` line filled in, so both share every function by construction.
  pluginIndexMarker = "readonly property var plugins: []";
  pluginIndexSrc = builtins.readFile ../../shell/Commons/PluginIndex.qml;
  pluginIndexQml =
    assert lib.assertMsg (lib.hasInfix pluginIndexMarker pluginIndexSrc)
      "shell/Commons/PluginIndex.qml must contain the line '${pluginIndexMarker}'";
    writeText "PluginIndex.qml" (
      builtins.replaceStrings
        [ pluginIndexMarker ]
        [
          "readonly property var plugins: ${builtins.toJSON pluginsForQml}"
        ]
        pluginIndexSrc
    );

  # share/marchyo/shell/plugins.lock.json: every baked plugin with its store
  # path and pinned source. Written for every build (an empty list without
  # plugins) so `marchyo plugin list` always finds it.
  pluginsLockJson = writeText "plugins.lock.json" (
    builtins.toJSON (import ./plugin-lock.nix { inherit lib; } plugins)
  );

  # omarchy CLI shims the imported plugins call by bare name (added to the shell
  # wrapper PATH only when plugins are declared). omarchy-shell forwards an IPC
  # call to the running shell via `quickshell -p $MARCHYO_SHELL_ROOT ipc` (that
  # env var is set by the wrapper); for `shell toggle|summon|hide <id>` it
  # redirects to that plugin's own IPC target, since marchyo plugins own their
  # target (=id). omarchy-bar persists a plugin's inline setting into marchyo's
  # runtime overlay, which Commons/ShellConfig reads as pluginSettings and
  # shell.qml's applyWidget merges into the widget at load.
  omarchyShell = writeShellApplication {
    name = "omarchy-shell";
    runtimeInputs = [ quickshell ];
    text = ''
      # shellcheck disable=SC2154  # MARCHYO_SHELL_ROOT is set by the shell wrapper
      quiet=0
      if [ "''${1:-}" = "-q" ]; then
        quiet=1
        shift
      fi
      target="''${1:-}"
      method="''${2:-}"
      if [ "$#" -ge 2 ]; then shift 2; else shift "$#"; fi
      if [ "$target" = "shell" ]; then
        case "$method" in
          toggle | summon | hide)
            newtarget="''${1:-}"
            if [ "$method" = "summon" ]; then method="show"; fi
            target="$newtarget"
            set --
            ;;
        esac
      fi
      if [ "$quiet" = 1 ]; then
        quickshell -p "$MARCHYO_SHELL_ROOT" ipc -n call -- "$target" "$method" "$@" >/dev/null 2>&1 || exit 0
      else
        exec quickshell -p "$MARCHYO_SHELL_ROOT" ipc -n call -- "$target" "$method" "$@"
      fi
    '';
  };

  omarchyBar = writeShellApplication {
    name = "omarchy-bar";
    runtimeInputs = [
      jq
      coreutils
    ];
    text = ''
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
    '';
  };
in
stdenvNoCC.mkDerivation {
  pname = "marchyo-shell";
  version = "0.1.0";

  src = ../../shell;

  nativeBuildInputs = [
    makeWrapper
    gawk
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/marchyo/shell"
    cp -r . "$out/share/marchyo/shell/"
    install -Dm0644 ${colorQml} "$out/share/marchyo/shell/Commons/Color.qml"
    install -Dm0644 ${styleQml} "$out/share/marchyo/shell/Commons/Style.qml"
    install -Dm0644 ${themeQml} "$out/share/marchyo/shell/Commons/Theme.qml"
    install -Dm0644 ${configQml} "$out/share/marchyo/shell/Commons/Config.qml"
    install -Dm0644 ${pluginsLockJson} "$out/share/marchyo/shell/plugins.lock.json"

    # Shell plugins (Option A): copy each declared plugin under plugins/<id>/
    # and regenerate the index over the checked-in empty default. Skipped
    # entirely when no plugins are declared.
    ${lib.optionalString (plugins != [ ]) ''
      install -Dm0644 ${pluginIndexQml} "$out/share/marchyo/shell/Commons/PluginIndex.qml"
      mkdir -p "$out/share/marchyo/shell/plugins"
      ${lib.concatMapStringsSep "\n" (p: ''
        cp -r ${p} "$out/share/marchyo/shell/plugins/${p.marchyoPlugin.id}"
        chmod -R u+w "$out/share/marchyo/shell/plugins/${p.marchyoPlugin.id}"
        # Rewrite omarchy plugin imports onto the compat host namespace
        # (shell/compat) so vendored omarchy QML resolves marchyo's shim
        # instead of marchyo's own qs.Ui / qs.Commons (different API). Scoped to
        # the two omarchy module names; the plugin's source stays unmodified.
        find "$out/share/marchyo/shell/plugins/${p.marchyoPlugin.id}" -type f \( -name '*.qml' -o -name '*.js' \) -print0 \
          | xargs -0 -r sed -i -e 's/\bimport qs\.Ui\b/import qs.compat.Ui/g' -e 's/\bimport qs\.Commons\b/import qs.compat.Commons/g'
      '') plugins}
    ''}

    # Regenerate Commons/EmojiData.js's RAW rows from unicode-emoji's
    # emoji-test.txt (the checked-in rows are a dev subset). The parser
    # lives in the checked-in file; only the rows between the generated
    # markers are replaced, so there is exactly one implementation of
    # parse(). Marker text is grepped verbatim — see the header comment in
    # EmojiData.js: nothing else in the file may spell the markers.
    emojiJs="$out/share/marchyo/shell/Commons/EmojiData.js"
    gawk -f ${./emoji.awk} \
      "${unicode-emoji}/share/unicode/emoji/emoji-test.txt" > "$out/emoji-rows.txt"
    count=$(wc -l < "$out/emoji-rows.txt")
    if [ "$count" -lt 1000 ]; then
      echo "FAIL: emoji generation produced only $count rows (expected 1000+)" >&2
      exit 1
    fi
    # Delete the dev rows strictly between the markers, keep the markers,
    # then append the generated rows right after the opening marker.
    sed -i '/BEGIN-GENERATED/,/END-GENERATED/{/BEGIN-GENERATED/!{/END-GENERATED/!d;};}' "$emojiJs"
    sed -i "/BEGIN-GENERATED/r $out/emoji-rows.txt" "$emojiJs"
    rm "$out/emoji-rows.txt"
    # The spliced file must still carry its data and its closing bracket.
    if ! grep -q '"Smileys & Emotion|face-smiling|' "$emojiJs"; then
      echo "FAIL: EmojiData.js lost its data rows" >&2
      exit 1
    fi
    if ! grep -q '^];' "$emojiJs"; then
      echo "FAIL: EmojiData.js lost its closing bracket" >&2
      exit 1
    fi

    # The greeter config root: the checked-in greeter/ tree plus the same
    # generated Commons singletons as the shell (host-variant palette, scaled
    # geometry, theme fallback) and its own tool-path Config. An own root, not
    # a subdirectory of the shell, because Quickshell's qs.* namespace maps to
    # the config root — a nested dir would not see qs.Commons.
    mkdir -p "$out/share/marchyo/greeter/Commons"
    cp -r ${../../greeter}/. "$out/share/marchyo/greeter/"
    install -Dm0644 ${colorQml} "$out/share/marchyo/greeter/Commons/Color.qml"
    install -Dm0644 ${styleQml} "$out/share/marchyo/greeter/Commons/Style.qml"
    install -Dm0644 ${greeterThemeQml} "$out/share/marchyo/greeter/Commons/Theme.qml"
    install -Dm0644 ${greeterConfigQml} "$out/share/marchyo/greeter/Commons/Config.qml"

    # The wrapper owns the shell's runtime environment so neither of the two
    # recurring Qt warnings depends on session env (same philosophy as the
    # baked tool paths in Config.qml):
    #
    #   - TZDIR points Qt's tz database at NixOS's /etc/zoneinfo (the store
    #     tzdata paths are not in Qt's hardcoded /usr/share/zoneinfo search
    #     list, so without this Qt cannot map /etc/localtime to an IANA name
    #     and warns "Unable to determine system time zone" on every D-Bus
    #     QDateTime conversion). --set-default so a custom TZDIR wins, and
    #     /etc/zoneinfo follows the live symlink, so marchyo.autoTimezone
    #     (automatic-timezoned) zone changes still apply.
    #
    #   - QT_QPA_PLATFORMTHEME=gtk3 matches the session value modules/home/qt.nix
    #     sets, pinned here so the shell never depends on session-env quirks
    #     (e.g. a host overriding the session to qt5ct, which has no Qt6
    #     plugin; tray/notification themed icons would then resolve against
    #     hicolor and fail to load). The gtk3 platform theme reads marchyo's
    #     own GTK settings (modules/home/gtk.nix: icon theme "Adwaita").
    # When plugins are declared, expose the omarchy CLI shims and the runtime
    # tools imported omarchy plugins call by bare name (python3, notify-send,
    # curl, coreutils, hyprctl), and point omarchy-shell at this store shell via
    # MARCHYO_SHELL_ROOT. Gated so plugin-less hosts keep a lean closure/PATH.
    makeWrapper ${lib.getExe quickshell} "$out/bin/marchyo-shell" \
      --add-flags "-p $out/share/marchyo/shell" \
      --set-default TZDIR /etc/zoneinfo \
      --set QT_QPA_PLATFORMTHEME gtk3${
        lib.optionalString (plugins != [ ]) ''
          \
               --set MARCHYO_SHELL_ROOT "$out/share/marchyo/shell" \
               --prefix PATH : "${
                 lib.makeBinPath [
                   omarchyShell
                   omarchyBar
                   python3
                   libnotify
                   curl
                   coreutils
                   hyprland
                 ]
               }"''
      }

    # Greeter wrapper. TZDIR for the clock, like the shell; no
    # QT_QPA_PLATFORMTHEME — the greeter user has no GTK settings and no
    # themed icons are loaded.
    makeWrapper ${lib.getExe quickshell} "$out/bin/marchyo-greeter" \
      --add-flags "-p $out/share/marchyo/greeter" \
      --set-default TZDIR /etc/zoneinfo

    runHook postInstall
  '';

  meta = {
    description = "Marchyo Quickshell desktop shell and greetd greeter";
    homepage = "https://github.com/jylhis/marchyo";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "marchyo-shell";
  };
}
