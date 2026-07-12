{
  stdenvNoCC,
  lib,
  jylhis-design-src,
  ...
}:
let
  # Splash background comes from the Jylhis Design System bg token (tokens.json
  # is the source of truth — see modules/generic/jylhis-palette.nix). The splash
  # is always the Roast (dark) bg: the theme's PNG assets (logo, entry, lock)
  # are drawn for a dark backdrop, so a Paper variant needs new assets first.
  tokens = lib.importJSON "${jylhis-design-src}/tokens.json";
  bgHex = lib.removePrefix "#" tokens.palette.bg.dark;

  # Pure hex-string → int (e.g. "1a" → 26). Avoids depending on any specific
  # nixpkgs hex helper; built only from stringToCharacters/foldl'.
  hexDigits = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    a = 10;
    b = 11;
    c = 12;
    d = 13;
    e = 14;
    f = 15;
  };
  hexToInt =
    s:
    lib.foldl' (acc: ch: acc * 16 + hexDigits.${ch}) 0 (
      lib.stringToCharacters (lib.toLower s)
    );

  channel = offset: hexToInt (builtins.substring offset 2 bgHex);
  channelFloat = offset: toString (channel offset / 255.0);
in
stdenvNoCC.mkDerivation {
  pname = "plymouth-marchyo-theme";
  version = "v3.0.0";
  src = ./.;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/plymouth/themes/marchyo
    cp * $out/share/plymouth/themes/marchyo
    find $out/share/plymouth/themes/ -name \*.plymouth -exec sed -i "s@\/usr\/@$out\/@" {} \;
    substituteInPlace $out/share/plymouth/themes/marchyo/marchyo.script \
      --replace-fail "@bgR@" "${channelFloat 0}" \
      --replace-fail "@bgG@" "${channelFloat 2}" \
      --replace-fail "@bgB@" "${channelFloat 4}"
    substituteInPlace $out/share/plymouth/themes/marchyo/marchyo.plymouth \
      --replace-fail "@bgHex@" "${bgHex}"
    runHook postInstall
  '';
  meta = {
    description = "Marchyo splash screen. Forked from https://github.com/basecamp/marchyo/tree/2df8c5f7e0a2aafb8c9aacb322408d2ed7682ea5";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
