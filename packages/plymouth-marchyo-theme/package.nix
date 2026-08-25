{
  stdenvNoCC,
  lib,
  jylhis-design-src,
  resvg,
  imagemagick,
  jetbrains-mono,
  # Theme variant to bake into the splash. Plymouth runs at boot before any
  # runtime theme switch, so the assets are rendered once for whichever variant
  # the system is configured with (marchyo.theme.variant, wired in
  # modules/nixos/plymouth.nix). "dark" = Jylhis Field, "light" = Jylhis Sheet.
  variant ? "dark",
}:
let
  # All colors come from the Jylhis Design System tokens.json (the same source
  # of truth as modules/generic/jylhis-palette.nix). Every asset is generated
  # or recolored at build time, so a variant flip retints the whole splash.
  tokens = builtins.fromJSON (builtins.readFile "${jylhis-design-src}/tokens.json");
  key = if variant == "light" then "light" else "dark";
  color = name: tokens.palette.${name}.${key};
  synColor = name: tokens.syntax.${name}.${key};

  # Semantic role -> token mapping for the splash surfaces.
  logoColor = color "brand"; # benchmark-vermilion wordmark (large brand mark)
  caretColor = color "accent"; # the sweeping ">" — motion is interactive-ish
  # Sparkle particles borrow from the syntax palette (function/keyword/type),
  # mirroring the HTML preview's --sparkle-1/2/3 variables.
  sparkle1Color = synColor "syn-function";
  sparkle2Color = synColor "syn-keyword";
  sparkle3Color = synColor "syn-type";
  entryColor = color "border-strong"; # password field outline
  lockColor = color "text-muted"; # padlock glyph
  bulletColor = color "text"; # password bullets
  trackColor = color "surface"; # progress-bar track
  barColor = color "accent"; # progress-bar fill
  bgColor = color "bg"; # cover mask must match the window background exactly

  bgHex = lib.removePrefix "#" (color "bg");

  monoFont = "${jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Bold.ttf";

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

  channelFloat = hex: offset: toString (hexPairToInt (builtins.substring offset 2 hex) / 255.0);
  textHex = lib.removePrefix "#" (color "text");
in
stdenvNoCC.mkDerivation {
  pname = "plymouth-marchyo-theme";
  version = "v5.0.0";
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

    # Word marks: the splash alternates between the two
    # "marchyo": rasterize the reordered omarchy wordmark (logo.svg) in the
    # brand color at the same 800x188 the old static PNG shipped at.
    sed 's/@fill@/${logoColor}/' logo.svg > marchyo-logo.svg
    resvg --width 800 marchyo-logo.svg "$theme/marchyo.png"
    height=$(magick identify -format '%h' "$theme/marchyo.png")

    # "jylhis": JetBrains Mono Bold, brand color, matched to the same height.
    magick -background none -fill '${logoColor}' \
      -font '${monoFont}' -pointsize 300 label:jylhis \
      -resize x"$height" "$theme/jylhis.png"

    # Sweep assets
    # The ❯ caret: a bespoke chevron (caret.svg) so we don't depend on any
    # font shipping U+276F. Accent color, slightly under cap height.
    caret_h=$((height * 8 / 10))
    sed 's/@stroke@/${caretColor}/' caret.svg > caret-tinted.svg
    resvg --height "$caret_h" caret-tinted.svg "$theme/caret.png"

    # Sparkle particles: four-point stars in three syntax-palette tints,
    # ~1/6 cap height each.
    for pair in '1 ${sparkle1Color}' '2 ${sparkle2Color}' '3 ${sparkle3Color}'; do
      set -- $pair
      sed "s/@fill@/$2/" sparkle.svg > "sparkle-tinted-$1.svg"
      resvg --height $((height / 6)) "sparkle-tinted-$1.svg" "$theme/sparkle$1.png"
    done

    # Cover mask: solid bg-color rectangle the script slides over the active
    # word. Same color as the window background = invisible clipping. The
    # script tracks the cover's LEFT edge to the caret and lets it overhang
    # the word's right edge, so the mask must be wider than the widest word:
    # when the caret parks left of the word (word fully hidden) the mask is
    # shifted left by up to ~0.6 caret-widths, and a mask sized to exactly the
    # wordmark would fall short on the right, leaving a visible text sliver.
    # Pad by 2x the cap height (well over the largest leftward shift); the
    # extra only ever paints bg over bg. Slightly taller for anti-aliasing.
    wm_w=$(magick identify -format '%w' "$theme/marchyo.png")
    cover_w=$((wm_w + height * 2))
    magick -size "$cover_w"x$((height + 8)) xc:'${bgColor}' "$theme/cover.png"

    # Password-dialog chrome
    # Keep the omarchy glyph shapes but flatten their RGB to a palette color,
    # preserving the original alpha (anti-aliasing).
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
      --replace-fail "@bgHex@" "${bgHex}" \
      --replace-fail "@fgHex@" "${textHex}"
    substituteInPlace "$theme/marchyo.script" \
      --replace-fail "@bgR@" "${channelFloat bgHex 0}" \
      --replace-fail "@bgG@" "${channelFloat bgHex 2}" \
      --replace-fail "@bgB@" "${channelFloat bgHex 4}" \
      --replace-fail "@fgR@" "${channelFloat textHex 0}" \
      --replace-fail "@fgG@" "${channelFloat textHex 2}" \
      --replace-fail "@fgB@" "${channelFloat textHex 4}"
    find "$out/share/plymouth/themes/" -name \*.plymouth -exec sed -i "s@\/usr\/@$out\/@" {} \;

    runHook postInstall
  '';

  # Sanity-check the generated theme on every build. Cheap, and it guards the
  # two invariants the animation silently depends on: every Image() the script
  # loads exists, and the cover mask is pixel-identical to the background.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    theme=$out/share/plymouth/themes/marchyo

    # Every image the script references must exist and be non-empty.
    for img in $(grep -o 'Image("[^"]*")' "$theme/marchyo.script" | sed 's/Image("\(.*\)")/\1/' | sort -u); do
      test -s "$theme/$img" || { echo "missing or empty asset: $img"; exit 1; }
    done

    # No unsubstituted @placeholders@ may survive install.
    if grep -nE '@[A-Za-z]+@' "$theme/marchyo.script" "$theme/marchyo.plymouth"; then
      echo "unsubstituted placeholder(s) remain"; exit 1
    fi

    # The .plymouth must point at this store path, not /usr.
    grep -q "ImageDir=$theme" "$theme/marchyo.plymouth"
    grep -q "ScriptFile=$theme/marchyo.script" "$theme/marchyo.plymouth"

    # Geometry invariants of the sweep: both wordmarks share a cap height, and
    # the cover mask is at least as wide as the widest word.
    mh=$(magick identify -format '%h' "$theme/marchyo.png")
    jh=$(magick identify -format '%h' "$theme/jylhis.png")
    test "$mh" = "$jh" || { echo "wordmark heights differ: marchyo=$mh jylhis=$jh"; exit 1; }
    mw=$(magick identify -format '%w' "$theme/marchyo.png")
    cw=$(magick identify -format '%w' "$theme/cover.png")
    test "$cw" -ge "$mw" || { echo "cover ($cw) narrower than marchyo wordmark ($mw)"; exit 1; }

    # The cover must be exactly the background color or the "clipping" shows.
    cover_hex=$(magick "$theme/cover.png" -format '%[hex:p{1,1}]' info: | tr 'A-F' 'a-f' | cut -c1-6)
    test "$cover_hex" = "${bgHex}" || { echo "cover color #$cover_hex != bg #${bgHex}"; exit 1; }

    runHook postInstallCheck
  '';

  # The baked variant, observable at eval time (used by tests/eval/plymouth.nix
  # to prove modules/nixos/plymouth.nix forwards marchyo.theme.variant).
  passthru = { inherit variant; };

  meta = {
    # Two word marks — the omarchy "marchyo" (basecamp/omarchy, leading "o"
    # moved to the end) and a JetBrains Mono "jylhis" — which the ">" caret
    # wipes on and off alternately at boot (see marchyo.script). Every
    # surface is themed from the Jylhis Design System tokens.json at build.
    description = "Marchyo Plymouth boot splash — alternating caret-wipe wordmarks, themed from Jylhis Design System tokens";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
