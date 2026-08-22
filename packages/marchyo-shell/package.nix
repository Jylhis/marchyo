{
  lib,
  stdenvNoCC,
  quickshell,
  makeWrapper,
  jylhis-design-src,
  # "dark" = Jylhis Field, "light" = Jylhis Sheet — matches marchyo.theme.variant.
  variant ? "dark",
  # marchyo.theme.fontScale — every bar dimension derives from it via
  # lib/font-scale.nix, so the shell scales with the rest of the desktop.
  fontScale ? 1.0,
  # marchyo.dictation.{enable,indicator} — bakes the dictation bar widget in/out
  # (the shell reads no runtime config yet; parity with waybar's voxtypeIndicator).
  dictationIndicator ? false,
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
      readonly property int spacing: ${toString (fs.round 8)}
      readonly property int paddingH: ${toString (fs.round 10)}
      readonly property string fontFamily: "monospace"

      // Baked feature flags (parity with waybar's conditional widgets).
      readonly property bool dictationIndicator: ${lib.boolToString dictationIndicator}
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

    makeWrapper ${lib.getExe quickshell} "$out/bin/marchyo-shell" \
      --add-flags "-p $out/share/marchyo/shell"

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
