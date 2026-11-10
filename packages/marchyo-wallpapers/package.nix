{
  lib,
  stdenvNoCC,
  resvg,
  jylhis-design-src,
}:
let
  tokens = (import "${jylhis-design-src}/nix/palette.nix" { inherit lib; }).theme;

  color = name: mode: tokens.palette.${name}.${mode};

  width = 3840;
  height = 2160;

  svg = body: ''
    <svg xmlns="http://www.w3.org/2000/svg" width="${toString width}" height="${toString height}" viewBox="0 0 ${toString width} ${toString height}">
    ${body}
    </svg>
  '';

  vignette = mode: opacity: ''
    <defs>
      <radialGradient id="accent-vignette" cx="50%" cy="18%" r="72%">
        <stop offset="0%" stop-color="${color "accent" mode}" stop-opacity="${opacity}"/>
        <stop offset="60%" stop-color="${color "accent" mode}" stop-opacity="0"/>
        <stop offset="100%" stop-color="${color "accent" mode}" stop-opacity="0"/>
      </radialGradient>
    </defs>
  '';

  full = fill: ''<rect width="${toString width}" height="${toString height}" fill="${fill}"/>'';

  # Concentric rings around two off-centre origins read as a contour map.
  contourRings =
    mode: opacity:
    let
      ring =
        {
          cx,
          cy,
          step,
          count,
        }:
        lib.concatMapStrings (
          i:
          let
            r = toString (step * (i + 1));
            ry = toString (step * (i + 1) * 0.68);
            drift = toString (i * 7);
          in
          ''
            <ellipse cx="${toString (cx + i * 7)}" cy="${toString cy}" rx="${r}" ry="${ry}" transform="rotate(-12 ${drift} ${toString cy})" fill="none" stroke="${color "contour" mode}" stroke-opacity="${opacity}" stroke-width="2"/>
          ''
        ) (lib.range 0 (count - 1));
    in
    ring {
      cx = 2760;
      cy = 640;
      step = 150;
      count = 20;
    }
    + ring {
      cx = 760;
      cy = 1700;
      step = 90;
      count = 8;
    };

  patterns = {
    grid =
      {
        mode,
        strength,
        vignetteOpacity,
      }:
      svg ''
        <defs>
          <pattern id="grid" width="48" height="48" patternUnits="userSpaceOnUse">
            <path d="M 48 0 H 0 V 48" fill="none" stroke="${color "border-strong" mode}" stroke-opacity="${strength}" stroke-width="1"/>
          </pattern>
        </defs>
        ${vignette mode vignetteOpacity}
        ${full (color "bg" mode)}
        ${full "url(#grid)"}
        ${full "url(#accent-vignette)"}
      '';

    dots =
      {
        mode,
        strength,
        vignetteOpacity,
      }:
      svg ''
        <defs>
          <pattern id="dots" width="64" height="64" patternUnits="userSpaceOnUse">
            <circle cx="32" cy="32" r="2.5" fill="${color "border-strong" mode}" fill-opacity="${strength}"/>
          </pattern>
        </defs>
        ${vignette mode vignetteOpacity}
        ${full (color "bg" mode)}
        ${full "url(#dots)"}
        ${full "url(#accent-vignette)"}
      '';

    bands =
      {
        mode,
        strength,
        vignetteOpacity,
      }:
      svg ''
        <defs>
          <pattern id="bands" width="320" height="320" patternUnits="userSpaceOnUse" patternTransform="rotate(-28)">
            <rect width="320" height="120" fill="${color "bg-subtle" mode}" fill-opacity="${strength}"/>
          </pattern>
        </defs>
        ${vignette mode vignetteOpacity}
        ${full (color "bg" mode)}
        ${full "url(#bands)"}
        ${full "url(#accent-vignette)"}
      '';

    contour =
      {
        mode,
        strength,
        vignetteOpacity,
      }:
      svg ''
        ${vignette mode vignetteOpacity}
        ${full (color "bg" mode)}
        ${contourRings mode strength}
        ${full "url(#accent-vignette)"}
      '';
  };

  # Per-polarity strength of the pattern layer and of the accent vignette.
  modes = {
    light = {
      grid = {
        strength = "0.20";
        vignetteOpacity = "0.10";
      };
      dots = {
        strength = "0.34";
        vignetteOpacity = "0.10";
      };
      bands = {
        strength = "0.70";
        vignetteOpacity = "0.08";
      };
      contour = {
        strength = "0.30";
        vignetteOpacity = "0.08";
      };
    };
    dark = {
      grid = {
        strength = "0.12";
        vignetteOpacity = "0.09";
      };
      dots = {
        strength = "0.22";
        vignetteOpacity = "0.09";
      };
      bands = {
        strength = "0.80";
        vignetteOpacity = "0.08";
      };
      contour = {
        strength = "0.20";
        vignetteOpacity = "0.08";
      };
    };
  };

  # { "jylhis-grid-light" = <svg file>; ... }
  svgs = lib.listToAttrs (
    lib.concatMap (
      mode:
      map (
        kind:
        let
          name = "jylhis-${kind}-${mode}";
        in
        lib.nameValuePair name (
          builtins.toFile "${name}.svg" (patterns.${kind} ({ inherit mode; } // modes.${mode}.${kind}))
        )
      ) (lib.attrNames patterns)
    ) (lib.attrNames modes)
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "marchyo-wallpapers";
  version = "0.2.0";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    dir="$out/share/marchyo/wallpapers"
    mkdir -p "$dir"
    ${lib.concatStrings (
      lib.mapAttrsToList (name: file: ''
        install -Dm0644 ${file} "$dir/${name}.svg"
        ${lib.getExe resvg} --width ${toString width} --height ${toString height} \
          "$dir/${name}.svg" "$dir/${name}.png"
      '') svgs
    )}

    runHook postInstall
  '';

  passthru = {
    light = "${finalAttrs.finalPackage}/share/marchyo/wallpapers/jylhis-grid-light.png";
    dark = "${finalAttrs.finalPackage}/share/marchyo/wallpapers/jylhis-grid-dark.png";
    # Every generated PNG of one polarity, default first.
    forPolarity =
      mode:
      map (kind: "${finalAttrs.finalPackage}/share/marchyo/wallpapers/jylhis-${kind}-${mode}.png") (
        [ "grid" ] ++ lib.filter (k: k != "grid") (lib.attrNames patterns)
      );
  };

  meta = {
    description = "Jylhis token-derived generated wallpapers for Marchyo";
    homepage = "https://github.com/jylhis/marchyo";
    license = lib.licenses.mit;
    platforms = resvg.meta.platforms;
  };
})
