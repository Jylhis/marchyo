{
  lib,
  stdenvNoCC,
  quickshell,
  makeWrapper,
  jylhis-design-src,
  # "dark" = Jylhis Field, "light" = Jylhis Sheet — matches marchyo.theme.variant.
  variant ? "dark",
}:
let
  tokens = builtins.fromJSON (builtins.readFile "${jylhis-design-src}/tokens.json");
  # Design tokens are palette.<name>.{dark,light}; variant is that key directly.
  color = name: tokens.palette.${name}.${variant};

  # Generated design-token color singleton, overwriting the checked-in dev
  # default so the store shell is themed to the host's variant. Same
  # tokens.json-driven, build-time generation idiom as marchyo-wallpapers.
  colorQml = builtins.toFile "Color.qml" ''
    pragma Singleton
    import QtQuick

    // Generated from the Jylhis design system (tokens.json), variant "${variant}".
    QtObject {
      readonly property color background: "${color "bg"}"
      readonly property color foreground: "${color "text"}"
      readonly property color accent: "${color "accent"}"
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

    makeWrapper ${lib.getExe quickshell} "$out/bin/marchyo-shell" \
      --add-flags "-p $out/share/marchyo/shell"

    runHook postInstall
  '';

  meta = {
    description = "Marchyo Quickshell desktop shell (Phase 0 spike)";
    homepage = "https://github.com/jylhis/marchyo";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "marchyo-shell";
  };
}
