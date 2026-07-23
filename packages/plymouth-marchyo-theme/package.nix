{
  stdenvNoCC,
  lib,
  jylhis-design-src,
  resvg,
  imagemagick,
  # Theme variant to bake into the splash. Plymouth runs at boot before any
  # runtime theme switch, so the assets are rendered once for whichever variant
  # the system is configured with (marchyo.theme.variant, wired in
  # modules/nixos/plymouth.nix). "dark" = Jylhis Roast, "light" = Jylhis Paper.
  variant ? "dark",
}:
let
  # All colors come from the Jylhis Design System tokens.json (the same source
  # of truth as modules/generic/jylhis-palette.nix). Every asset is generated
  # or recolored at build time, so a variant flip retints the whole splash.
  tokens = builtins.fromJSON (builtins.readFile "${jylhis-design-src}/tokens.json");
  key = if variant == "light" then "light" else "dark";
  color = name: tokens.palette.${name}.${key};

  # Semantic role -> token mapping for the splash surfaces.
  logoColor = color "brand"; # copper wordmark (large brand mark)
  entryColor = color "border-strong"; # password field outline
  lockColor = color "text-muted"; # padlock glyph
  bulletColor = color "text"; # password bullets
  trackColor = color "surface"; # progress-bar track
  barColor = color "accent"; # progress-bar fill

  bgHex = lib.removePrefix "#" (color "bg");

  # Pure hex -> int for one color channel. Nixpkgs ships no standard hex parser,
  # so map each nibble through a lookup and combine the two digits of the pair.
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
  hexPairToInt =
    pair: 16 * hexDigits.${builtins.substring 0 1 pair} + hexDigits.${builtins.substring 1 1 pair};

  channel = offset: hexPairToInt (builtins.substring offset 2 bgHex);
  channelFloat = offset: toString (channel offset / 255.0);
in
stdenvNoCC.mkDerivation {
  pname = "plymouth-marchyo-theme";
  version = "v4.0.0";
  src = ./.;

  nativeBuildInputs = [
    resvg
    imagemagick
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    theme=share/plymouth/themes/marchyo
    mkdir -p "$theme"

    # Logo: rasterize the reordered "marchyo" wordmark (logo.svg) in brand
    # copper at the same 800x188 the old static PNG shipped at.
    sed 's/@fill@/${logoColor}/' logo.svg > marchyo-logo.svg
    resvg --width 800 marchyo-logo.svg "$theme/logo.png"

    # Password-dialog chrome: keep the omarchy glyph shapes but flatten their
    # RGB to a palette color, preserving the original alpha (anti-aliasing).
    magick entry.png  -channel RGB -fill "${entryColor}"  -colorize 100 "$theme/entry.png"
    magick lock.png   -channel RGB -fill "${lockColor}"   -colorize 100 "$theme/lock.png"
    magick bullet.png -channel RGB -fill "${bulletColor}" -colorize 100 "$theme/bullet.png"

    # Progress bar: solid palette fills at the original 300x10 geometry.
    magick -size 300x10 xc:"${trackColor}" "$theme/progress_box.png"
    magick -size 300x10 xc:"${barColor}"   "$theme/progress_bar.png"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    theme=$out/share/plymouth/themes/marchyo
    mkdir -p "$theme"
    cp -r --reflink=auto share/plymouth/themes/marchyo/* "$theme"/

    cp --reflink=auto marchyo.plymouth marchyo.script "$theme"/
    substituteInPlace "$theme/marchyo.plymouth" \
      --replace-fail "@bgHex@" "${bgHex}"
    substituteInPlace "$theme/marchyo.script" \
      --replace-fail "@bgR@" "${channelFloat 0}" \
      --replace-fail "@bgG@" "${channelFloat 2}" \
      --replace-fail "@bgB@" "${channelFloat 4}"
    find "$out/share/plymouth/themes/" -name \*.plymouth -exec sed -i "s@\/usr\/@$out\/@" {} \;

    runHook postInstall
  '';

  meta = {
    # Logo generated from the omarchy wordmark (basecamp/omarchy) with the
    # leading "o" moved to the end; every surface is themed from the Jylhis
    # Design System tokens.json at build time (per variant). See the header.
    description = "Marchyo Plymouth boot splash, generated and themed from Jylhis Design System tokens";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
