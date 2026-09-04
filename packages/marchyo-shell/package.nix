{
  lib,
  stdenvNoCC,
  quickshell,
  makeWrapper,
  writeText,
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
  vicinae,
  marchyo-cli,
  # "dark" = Jylhis Field, "light" = Jylhis Sheet — matches marchyo.theme.variant.
  variant ? "dark",
  # marchyo.theme.fontScale — every bar dimension derives from it via
  # lib/font-scale.nix, so the shell scales with the rest of the desktop.
  fontScale ? 1.0,
  # marchyo.dictation.{enable,indicator} — bakes the dictation bar widget in/out
  # (the shell reads no runtime config yet; parity with waybar's voxtypeIndicator).
  dictationIndicator ? false,
  # marchyo.menus.enable — drives the battery click target (marchyo menu power vs
  # vicinae toggle), matching waybar's menusEnabled gate.
  menusEnabled ? true,
}:
let
  # Reuse the design-system palette helper (single source of truth for token ->
  # hex resolution and the palette/status/syntax merge) rather than re-reading
  # tokens.json here. It only touches pkgs.jylhis-design-src, so a one-attr stub
  # is enough in this callPackage context. Same idiom as modules/home/vicinae.nix.
  palette = import ../../modules/generic/jylhis-palette.nix {
    pkgs = { inherit jylhis-design-src; };
    inherit lib variant;
  };
  fs = import ../../lib/font-scale.nix {
    inherit lib;
    scale = fontScale;
  };

  # Bar colors: every palette + status token, minus syntax-highlighting tokens
  # (syn-*) which no UI surface uses. QML identifiers can't contain hyphens, so
  # bg-subtle -> bgSubtle, status-err -> statusErr, etc.
  hex = lib.filterAttrs (n: _: !lib.hasPrefix "syn-" n) palette.hex;
  toCamel =
    s:
    let
      parts = lib.splitString "-" s;
      cap = w: lib.toUpper (lib.substring 0 1 w) + lib.substring 1 (lib.stringLength w) w;
    in
    lib.concatStrings (lib.imap0 (i: w: if i == 0 then w else cap w) parts);
  colorLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: ''readonly property color ${toCamel name}: "${value}"'') hex
  );

  # Generated design-token color singleton, overwriting the checked-in dev
  # default so the store shell is themed to the host's variant. Same
  # tokens.json-driven, build-time generation idiom as marchyo-wallpapers.
  colorQml = builtins.toFile "Color.qml" ''
    pragma Singleton
    import QtQuick

    // Generated from the Jylhis design system (tokens.json), variant "${variant}".
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
      readonly property int barHeight: ${toString (fs.round 28)}
      readonly property int fontSize: ${toString (fs.round 14)}
      readonly property int fontSizeSmall: ${toString (fs.round 12)}
      readonly property int spacing: ${toString (fs.round 4)}
      readonly property int paddingH: ${toString (fs.round 6)}
      readonly property string fontFamily: "BlexMono Nerd Font"

      // On-screen-display geometry (volume/brightness overlay).
      readonly property int osdPad: ${toString (fs.round 14)}
      readonly property int osdRadius: ${toString (fs.round 8)}
      readonly property int osdMargin: ${toString (fs.round 80)}
      readonly property int osdBarWidth: ${toString (fs.round 140)}
      readonly property int osdBarHeight: ${toString (fs.round 6)}

      // Summonable-panel geometry (audio/network/power/monitor cards under the bar).
      readonly property int panelWidth: ${toString (fs.round 260)}
      readonly property int panelPad: ${toString (fs.round 14)}
      readonly property int panelGap: ${toString (fs.round 6)}
      readonly property int panelRadius: ${toString (fs.round 8)}
      readonly property int panelRowHeight: ${toString (fs.round 30)}

      // Notification-toast geometry (replaces mako; mako uses width 380, pad 8,
      // radius 0 sharp corners, border 2, margin 10). Pixel sizes scale with the
      // font; the timeouts are milliseconds and stay unscaled.
      readonly property int notifWidth: ${toString (fs.round 380)}
      readonly property int notifPad: ${toString (fs.round 12)}
      readonly property int notifRadius: 0
      readonly property int notifBorder: 2
      readonly property int notifGap: ${toString (fs.round 8)}
      readonly property int notifMargin: ${toString (fs.round 10)}
      readonly property int notifIconSize: ${toString (fs.round 40)}
      readonly property int notifMaxVisible: 5
      readonly property int notifTimeoutLow: 5000
      readonly property int notifTimeoutNormal: 5000
      readonly property int notifTimeoutCritical: 0

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
      readonly property string vicinae: "${lib.getExe vicinae}"
      readonly property string marchyo: "${lib.getExe marchyo-cli}"
    }
  '';
in
stdenvNoCC.mkDerivation {
  pname = "marchyo-shell";
  version = "0.1.0";

  src = ../../shell;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/marchyo/shell"
    cp -r . "$out/share/marchyo/shell/"
    install -Dm0644 ${colorQml} "$out/share/marchyo/shell/Commons/Color.qml"
    install -Dm0644 ${styleQml} "$out/share/marchyo/shell/Commons/Style.qml"
    install -Dm0644 ${configQml} "$out/share/marchyo/shell/Commons/Config.qml"

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
    #   - QT_QPA_PLATFORMTHEME=gtk3 makes the Qt6 shell read marchyo's GTK
    #     settings (modules/home/gtk.nix: icon theme "Adwaita"). The session
    #     value is typically "qt5ct" (HM qt module via stylix), which has no
    #     Qt6 platform-theme plugin — without the override, tray and
    #     notification themed icons resolve against hicolor and fail
    #     ("Could not load icon ... from request").
    makeWrapper ${lib.getExe quickshell} "$out/bin/marchyo-shell" \
      --add-flags "-p $out/share/marchyo/shell" \
      --set-default TZDIR /etc/zoneinfo \
      --set QT_QPA_PLATFORMTHEME gtk3

    runHook postInstall
  '';

  meta = {
    description = "Marchyo Quickshell desktop shell (Phase 1: bar)";
    homepage = "https://github.com/jylhis/marchyo";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "marchyo-shell";
  };
}
