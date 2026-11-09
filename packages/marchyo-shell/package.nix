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
  # relies on the session PATH.
  ghostty,
  hyprland,
  voxtype,
  wiremix,
  btop,
  networkmanager,
  bluetui,
  procps,
  coreutils,
  bash,
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
  imagemagick,
  findutils,
  inotify-tools,
  brightnessctl,
  ddcutil,
  uwsm,
  systemd,
  # "dark" = Jylhis Dark, "light" = Jylhis Light — matches marchyo.theme.variant.
  variant ? "dark",
  # marchyo.theme.fontScale — every bar dimension derives from it via
  # lib/font-scale.nix, so the shell scales with the rest of the desktop.
  fontScale ? 1.0,
  # marchyo.dictation.{enable,indicator} — bakes the dictation bar widget in/out
  # (the shell reads no runtime config yet).
  dictationIndicator ? false,
  # marchyo.dictation.backend — picks how the indicator learns the state
  # (voxtype's status stream, or `marchyo dictation status` polling).
  dictationBackend ? "voxtype",
  # marchyo.menus.enable — drives the power panel's menu button (marchyo menu
  # power vs the in-shell app launcher).
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
  # marchyo.language: default display language of the shell strings
  # (Commons/I18n.qml); `marchyo language <code>` overrides it at runtime.
  language ? "en",
  # marchyo.workspaces.perMonitor: the bar labels each monitor's block of ten
  # workspaces 1-10 (Bar/WorkspacesWidget.qml).
  perMonitorWorkspaces ? true,
  # marchyo.monitorPanel.persist: the display panel saves its changes to
  # $XDG_STATE_HOME/marchyo/monitors/settings.
  monitorPersist ? true,
  # marchyo.notifications.rules — per-sender notification rules, baked as a QML
  # array literal (JSON is valid JS). Empty by default. See Services/Notification
  # State.qml for the match/apply logic.
  notifRules ? [ ],
  # marchyo.notifications.stackBySender / detectCodes / passApps.
  notifStackBySender ? true,
  notifDetectCodes ? true,
  notifPassApps ? [ "marchyo" ],
  # marchyo.theme.appearance.* — palette-independent scale axes (Caelestia's
  # split). Neutral defaults reproduce the current look.
  cornerRadiusScale ? 1.0,
  uiScale ? 1.0,
  animationSpeed ? 1.0,
  reduceMotion ? false,
  highContrast ? false,
  # marchyo.theme.appearance.floatingBar / surfaceAlpha — the Caelestia-inspired
  # style axes: a detached rounded pill bar instead of the full-width strip, and
  # translucent glass surfaces (alpha < 1 pairs with the Hyprland blur layer
  # rules modules/home/hyprland.nix registers for the shell's namespaces).
  floatingBar ? false,
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
  # is enough in this callPackage context.
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
  animMs = base: if reduceMotion then 0 else builtins.floor (base / animationSpeed + 0.5);

  # Jylhis dimension and motion tokens (tokens/base.tokens.json) that the
  # palette reader does not expose: the focus ring and marker widths, and the
  # motion durations in ms.
  baseTokens = builtins.fromJSON (builtins.readFile "${jylhis-design-src}/tokens/base.tokens.json");
  borderPx = name: baseTokens.border.${name}."$value".value;
  motionMs = name: baseTokens.motion.${name}."$value".duration.value;
  spaceSteps = [ "2xs" "xs" "sm" "md" "lg" "xl" "2xl" "3xl" ];
  # `space` tokens are rem (16 px); the UI scale applies on top.
  spacePx = name: ui.round (baseTokens.space.${name}."$value".value * 16);

  # Commons/Theme.qml and the greeter's Theme.qml carry a dev-default palette
  # as `<camelName>: "#rrggbb"` lines. Fill each line from the host variant's
  # palette by its property name, never by matching the old hex: a hex swap
  # cannot tell apart tokens that share a value in one variant (design 5.0 ink
  # is text, rule and link by day), and it silently skips stale literals.
  # A name with no palette token keeps its literal.
  hexByCamel = lib.mapAttrs' (n: v: lib.nameValuePair (toCamel n) v) palette.hex;
  fillThemeLine =
    line:
    let
      m = builtins.match "([[:space:]]*)([A-Za-z0-9]+): \"#[0-9a-fA-F]{6}\"(,?)" line;
      name = builtins.elemAt m 1;
    in
    if m == null || !(hexByCamel ? ${name}) then
      line
    else
      "${builtins.head m}${name}: \"${hexByCamel.${name}}\"${builtins.elemAt m 2}";
  # The generated Colors.qml binds Theme.palette.<camel> for every token in
  # `hex`, so the fallback must define every one of them; the dev fallback
  # lists only the tokens the dev tree uses. Every missing token is added
  # right after the fallback palette's opening line (shell:
  # `property var palette: ({`, greeter: `readonly property var baked: ({`);
  # the assert keeps a reworded opener from making the injection a no-op.
  paletteOpen = "[[:space:]]*(readonly )?property var (palette|baked): \\(\\{";
  themeQmlFor =
    devThemePath:
    let
      lines = lib.splitString "\n" (builtins.readFile devThemePath);
      present = lib.filter (n: n != null) (
        map (
          line:
          let
            m = builtins.match "[[:space:]]*([A-Za-z0-9]+): \"#[0-9a-fA-F]{6}\",?" line;
          in
          if m == null then null else builtins.head m
        ) lines
      );
      missing = lib.filter (n: !(lib.elem n present)) (map toCamel (lib.attrNames hex));
      missingLines = map (n: "            ${n}: \"${hexByCamel.${n}}\",") missing;
      inject = line: [ line ] ++ lib.optionals (builtins.match paletteOpen line != null) missingLines;
    in
    assert lib.assertMsg (lib.any (l: builtins.match paletteOpen l != null) lines)
      "marchyo-shell: no fallback palette opener (`property var palette|baked: ({`) in ${toString devThemePath}";
    writeText "Theme.qml" (lib.concatStringsSep "\n" (lib.concatMap inject (map fillThemeLine lines)));
  themeQml = themeQmlFor ../../shell/Commons/Theme.qml;
  greeterThemeQml = themeQmlFor ../../greeter/Commons/Theme.qml;

  # Bar colors: every palette + status token, minus syntax-highlighting tokens
  # (syn-*) which no UI surface uses.
  hex = lib.filterAttrs (n: _: !lib.hasPrefix "syn-" n) palette.hex;
  toCamel = lib.toCamelCase;
  colorLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: _: "readonly property color ${toCamel name}: Theme.palette.${toCamel name}"
    ) hex
  );

  # Generated color singleton, overwriting the checked-in dev default (which
  # carries the same delegation): every token binds Theme.palette.<camel> so
  # the whole bar live-recolors on `marchyo theme set`. Theme.qml below bakes
  # the host-variant fallback palette; this file is variant-independent.
  colorQml = builtins.toFile "Colors.qml" ''
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

      // Jylhis spacing scale in px (tokens/base.tokens.json `space`), scaled
      // with the UI.
      readonly property var spaceScale: ({
${lib.concatMapStringsSep ",\n" (n: "        \"${n}\": ${toString (spacePx n)}") spaceSteps}
      })

      // One step of the spacing scale; an unknown step reads as "sm".
      function space(step: string): int {
        const px = spaceScale[step];
        return px === undefined ? spaceScale.sm : px;
      }

      readonly property int barItemPad: space("xs")
      readonly property string baseFontFamily: "BlexMono Nerd Font"
      // Shell font: the runtime UI font (Services/RuntimeStyle, `marchyo font set
      // --kind ui`) over the baked family.
      property string uiFont: ""
      readonly property string fontFamily: uiFont !== "" ? uiFont : baseFontFamily

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

      // Runtime bar switches, written by Services/RuntimeStyle from
      // `marchyo theme bar-position` and `marchyo theme bar-background`. An empty
      // barBackground keeps the surfaceAlpha look above.
      property string barPosition: "top"
      property string barBackground: ""
      readonly property bool barBottom: barPosition === "bottom"
      readonly property real barAlpha: barBackground === "opaque" ? 1.0 : barBackground === "clear" ? 0.0 : barBackground === "glassy" ? Math.min(surfaceAlpha, 0.6) : surfaceAlpha

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

      // Notification-toast geometry. Pixel sizes scale with the font; the
      // timeouts are milliseconds and stay unscaled.
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
      readonly property bool notifStackBySender: ${lib.boolToString notifStackBySender}
      readonly property bool notifDetectCodes: ${lib.boolToString notifDetectCodes}
      readonly property var notifPassApps: ${builtins.toJSON notifPassApps}

      // Appearance scale axes (marchyo.theme.appearance).
      readonly property int animationDuration: ${toString (animMs 150)}
      readonly property bool highContrast: ${lib.boolToString highContrast}
      readonly property int borderWidth: ${toString (if highContrast then 2 else 1)}
      readonly property real animationSpeed: ${toString animationSpeed}
      readonly property bool reduceMotion: ${lib.boolToString reduceMotion}

      // Jylhis motion tokens (ms): press sink, colour ease, base, slow, long.
      // motionLong is the budget no transition may exceed (tests/shell/motion-budget-test.js).
      readonly property int motionPress: ${toString (motionMs "press")}
      readonly property int motionFast: ${toString (motionMs "fast")}
      readonly property int motionBase: ${toString (motionMs "base")}
      readonly property int motionSlow: ${toString (motionMs "slow")}
      readonly property int motionLong: ${toString (motionMs "long")}

      // Runtime switches: the reduce-motion override (Services/RuntimeStyle) and
      // Hyprland's animations:enabled probe (Services/Motion).
      property bool motionRuntimeOff: false
      property bool compositorAnimationsOff: false

      // Every transition length goes through here: 0 when motion is reduced at
      // build time, by the runtime toggle, or by the compositor.
      function duration(ms: int): int {
        if (reduceMotion || motionRuntimeOff || compositorAnimationsOff)
          return 0;
        return Math.max(0, Math.round(ms / animationSpeed));
      }

      // Jylhis border tokens: hairline is borderWidth (wider under high
      // contrast), the focus ring and the selected-item marker are wider still.
      readonly property int borderFocus: ${
        toString (borderPx "focus" + (if highContrast then 1 else 0))
      }
      readonly property int borderMarker: ${toString (borderPx "marker")}

      // Control states (normal, hover, focus, selected, pressed): fill colour,
      // fill alpha and border. Colours follow the live theme through Colors.
      readonly property var controls: ({
          normal: {
            fill: Colors.bgSubtle,
            fillAlpha: 1.0,
            border: Colors.border,
            borderWidth: borderWidth
          },
          hover: {
            fill: Colors.surfaceRaised,
            fillAlpha: 1.0,
            border: Colors.borderStrong,
            borderWidth: borderWidth
          },
          focus: {
            fill: Colors.bgSubtle,
            fillAlpha: 1.0,
            border: Colors.focusRing,
            borderWidth: borderFocus
          },
          selected: {
            fill: Colors.accentSubtle,
            fillAlpha: 1.0,
            border: Colors.accent,
            borderWidth: borderWidth
          },
          pressed: {
            fill: Colors.selectionBg,
            fillAlpha: 1.0,
            border: Colors.borderStrong,
            borderWidth: borderWidth
          }
        })

      function control(state: string): var {
        return controls[state] || controls.normal;
      }

      // Whether to run the solaar HID++ fallback for peripherals battery.
      readonly property bool peripheralsFallback: ${lib.boolToString peripheralsFallback}

      // Baked feature flags.
      readonly property bool dictationIndicator: ${lib.boolToString dictationIndicator}
      readonly property string dictationBackend: "${dictationBackend}"
      readonly property bool menusEnabled: ${lib.boolToString menusEnabled}
    }
  '';

  # Thumbnail generator for the theme and wallpaper pickers (Services/Thumbnails).
  marchyoThumbs = writeShellApplication {
    name = "marchyo-thumbs";
    runtimeInputs = [
      coreutils
      findutils
      imagemagick
    ];
    text = builtins.readFile ./thumbs.sh;
  };

  # Generated tool-path singleton: absolute /nix/store paths for the binaries the
  # interactive widgets launch or probe, overwriting the checked-in dev default so
  # the store shell never depends on the session PATH.
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
      readonly property string date: "${lib.getExe' coreutils "date"}"
      readonly property string bash: "${lib.getExe bash}"
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
      readonly property string chmod: "${lib.getExe' coreutils "chmod"}"
      readonly property string mkdir: "${lib.getExe' coreutils "mkdir"}"
      readonly property string rm: "${lib.getExe' coreutils "rm"}"
      readonly property string inotifywait: "${lib.getExe' inotify-tools "inotifywait"}"
      readonly property string udevadm: "${lib.getExe' systemd "udevadm"}"
      readonly property string brightnessctl: "${lib.getExe brightnessctl}"
      readonly property string ddcutil: "${lib.getExe ddcutil}"
      readonly property string thumbs: "${lib.getExe marchyoThumbs}"
      readonly property string language: "${language}"
      readonly property bool perMonitorWorkspaces: ${lib.boolToString perMonitorWorkspaces}
      readonly property bool monitorPersist: ${lib.boolToString monitorPersist}
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
    install -Dm0644 ${colorQml} "$out/share/marchyo/shell/Commons/Colors.qml"
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
        # Rewrite plugin imports onto the compat host namespace
        # (shell/compat) so plugin QML written against that host API resolves
        # the shim instead of marchyo's own qs.Ui / qs.Commons (different API),
        # and a bare `Color.` read onto `CompatColor.` because Qt 6.12's
        # QtQuick `Color` singleton shadows the shim's under that name. The
        # plugin's source stays otherwise unmodified.
        find "$out/share/marchyo/shell/plugins/${p.marchyoPlugin.id}" -type f \( -name '*.qml' -o -name '*.js' \) -print0 \
          | xargs -0 -r sed -i -E \
            -e 's/(^|[^.A-Za-z0-9_])import qs\.Ui\b/\1import qs.compat.Ui/g' \
            -e 's/(^|[^.A-Za-z0-9_])import qs\.Commons\b/\1import qs.compat.Commons/g' \
            -e 's/(^|[^.A-Za-z0-9_])Color\.([A-Za-z])/\1CompatColor.\2/g' \
            -e 's/\bCommons\.Color\.([A-Za-z])/Commons.CompatColor.\1/g'
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
    install -Dm0644 ${colorQml} "$out/share/marchyo/greeter/Commons/Colors.qml"
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
    makeWrapper ${lib.getExe quickshell} "$out/bin/marchyo-shell" \
      --add-flags "-p $out/share/marchyo/shell" \
      --set-default TZDIR /etc/zoneinfo \
      --set QT_QPA_PLATFORMTHEME gtk3

    # Greeter wrapper. TZDIR for the clock, like the shell; no
    # QT_QPA_PLATFORMTHEME — the greeter user has no GTK settings and no
    # themed icons are loaded.
    makeWrapper ${lib.getExe quickshell} "$out/bin/marchyo-greeter" \
      --add-flags "-p $out/share/marchyo/greeter" \
      --set-default TZDIR /etc/zoneinfo

    runHook postInstall
  '';

  passthru = { inherit language; };

  meta = {
    description = "Marchyo Quickshell desktop shell and greetd greeter";
    homepage = "https://github.com/jylhis/marchyo";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "marchyo-shell";
  };
}
