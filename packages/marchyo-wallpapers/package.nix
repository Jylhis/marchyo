{
  lib,
  stdenvNoCC,
  resvg,
  jylhis-design-src,
}:
let
  tokens = builtins.fromJSON (builtins.readFile "${jylhis-design-src}/tokens.json");

  color = name: mode: tokens.palette.${name}.${mode};

  mkSvg =
    {
      mode,
      label,
      gridOpacity,
      vignetteOpacity,
    }:
    builtins.toFile "jylhis-grid-${label}.svg" ''
      <svg xmlns="http://www.w3.org/2000/svg" width="3840" height="2160" viewBox="0 0 3840 2160">
        <defs>
          <pattern id="grid" width="48" height="48" patternUnits="userSpaceOnUse">
            <path d="M 48 0 H 0 V 48" fill="none" stroke="${color "decorator" mode}" stroke-opacity="${gridOpacity}" stroke-width="1"/>
          </pattern>
          <radialGradient id="copper-vignette" cx="50%" cy="18%" r="72%">
            <stop offset="0%" stop-color="${color "accent" mode}" stop-opacity="${vignetteOpacity}"/>
            <stop offset="60%" stop-color="${color "accent" mode}" stop-opacity="0"/>
            <stop offset="100%" stop-color="${color "accent" mode}" stop-opacity="0"/>
          </radialGradient>
        </defs>
        <rect width="3840" height="2160" fill="${color "bg" mode}"/>
        <rect width="3840" height="2160" fill="url(#grid)"/>
        <rect width="3840" height="2160" fill="url(#copper-vignette)"/>
      </svg>
    '';

  lightSvg = mkSvg {
    mode = "light";
    label = "light";
    gridOpacity = "0.20";
    vignetteOpacity = "0.10";
  };

  darkSvg = mkSvg {
    mode = "dark";
    label = "dark";
    gridOpacity = "0.12";
    vignetteOpacity = "0.09";
  };
in
stdenvNoCC.mkDerivation {
  pname = "marchyo-wallpapers";
  version = "0.1.0";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm0644 ${lightSvg} "$out/share/marchyo/wallpapers/jylhis-grid-light.svg"
    install -Dm0644 ${darkSvg} "$out/share/marchyo/wallpapers/jylhis-grid-dark.svg"

    ${lib.getExe resvg} --width 3840 --height 2160 \
      "$out/share/marchyo/wallpapers/jylhis-grid-light.svg" \
      "$out/share/marchyo/wallpapers/jylhis-grid-light.png"

    ${lib.getExe resvg} --width 3840 --height 2160 \
      "$out/share/marchyo/wallpapers/jylhis-grid-dark.svg" \
      "$out/share/marchyo/wallpapers/jylhis-grid-dark.png"

    runHook postInstall
  '';

  passthru = {
    light = "${placeholder "out"}/share/marchyo/wallpapers/jylhis-grid-light.png";
    dark = "${placeholder "out"}/share/marchyo/wallpapers/jylhis-grid-dark.png";
  };

  meta = {
    description = "Jylhis token-derived grid wallpapers for Marchyo";
    homepage = "https://github.com/jylhis/marchyo";
    license = lib.licenses.mit;
    platforms = resvg.meta.platforms;
  };
}
