# Runtime theme switching, build-time asset layer.
#
# The declarative build-time variant (marchyo.theme.variant) stays the source
# of truth; this module additionally materializes every theme in
# marchyo.theme.themes as runtime-swappable asset dirs plus a manifest the
# `marchyo theme` CLI reads. The switch is an ephemeral overlay: the next
# activation resets every surface (and ~/.config/marchyo/current-theme) back
# to the declarative default. Qt (via Stylix), bat, fzf, starship, hyprlock,
# console and plymouth stay on the build-time default until rebuild.
#
# The dual-variant mako/waybar/gtk sources are derived from the resolved Home
# Manager config by translating the build variant's semantic-token hexes to
# the other variant's, so edits to those modules flow into both variants
# automatically. ANSI hexes are excluded (several collide with semantic tokens
# but map differently, and don't appear in these surfaces).
{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  themeCfg = (osConfig.marchyo or { }).theme or { };
  themeEnabled = themeCfg.enable or true;
  buildVariant = themeCfg.variant or "dark";
  otherVariant = if buildVariant == "dark" then "light" else "dark";

  mkPalette = variant: import ../generic/jylhis-palette.nix { inherit pkgs lib variant; };
  palettes = {
    dark = mkPalette "dark";
    light = mkPalette "light";
  };

  # Semantic-token hex translation: build variant → other variant (and, below,
  # → each base16 scheme). tokenNames is the stable `from` order for every swap.
  tokenNames = lib.attrNames palettes.dark.hex;
  hexesFor = v: map (n: palettes.${v}.hex.${n}) tokenNames;
  buildHexes = hexesFor buildVariant;

  # shade_color is the one decimal-literal colour the hex swap cannot reach: the
  # generated gtk css carries `rgba(<text rgb>, 0.08)` (mako/waybar carry none).
  # Translate it to the target palette's text rgb alongside the hex swap — for
  # the jylhis other variant (textFor) and every base16 scheme (swapGtkToScheme).
  hexByte = import ../../lib/hex-byte.nix { inherit lib; };
  rgbTriple =
    h:
    map (o: toString (hexByte (builtins.substring o 2 (lib.removePrefix "#" h)))) [
      0
      2
      4
    ];
  shadeRgba = h: "rgba(${lib.concatStringsSep ", " (rgbTriple h)}, 0.08)";
  swapShade =
    targetTextHex:
    builtins.replaceStrings
      [ (shadeRgba palettes.${buildVariant}.hex.text) ]
      [ (shadeRgba targetTextHex) ];

  # Guard the textual hex swap. `builtins.replaceStrings` applies the first
  # matching `from`, so two tokens that share a build-variant hex but diverge in
  # the target silently mis-colour the loser (e.g. status-info and syn-variable
  # are both #005e8a in light); and a colour literal that is not a build-variant
  # token hex (a hardcoded colour, an uppercase/shorthand/8-digit hex, an
  # ANSI-only value) would ship untranslated. Both fail the build here. Scoped
  # to the hexes a surface actually carries, so an unused collision elsewhere in
  # the palette is never a false positive.
  #
  # A colour literal is a `#` hex run whose following char is not an identifier
  # char, so a waybar CSS id selector (`#cpu`, `#battery`) — a `#` run butting
  # straight into more letters — is not mistaken for a colour. A shorthand or
  # 8-digit hex colour therefore still counts and, not being a 6-digit token
  # hex, is reported as unswappable.
  isIdentChar = c: builtins.match "[0-9A-Za-z_-]" c != null;
  hexRunsIn =
    text:
    let
      parts = builtins.split "#([0-9a-fA-F]+)" text;
      n = builtins.length parts;
      colorAt =
        i:
        let
          after = if i + 1 < n then builtins.elemAt parts (i + 1) else "";
        in
        lib.optional (after == "" || !(isIdentChar (builtins.substring 0 1 after))) (
          "#" + builtins.head (builtins.elemAt parts i)
        );
    in
    lib.concatMap (i: if builtins.isList (builtins.elemAt parts i) then colorAt i else [ ]) (
      lib.range 0 (n - 1)
    );
  targetsForHex =
    tos: hx:
    lib.unique (
      lib.concatMap (i: lib.optional (builtins.elemAt buildHexes i == hx) (builtins.elemAt tos i)) (
        lib.range 0 (builtins.length buildHexes - 1)
      )
    );
  assertRecolorable =
    label: tos: text:
    let
      present = lib.unique (hexRunsIn text);
      unswappable = lib.filter (hx: !(builtins.elem hx buildHexes)) present;
      ambiguous = lib.filter (hx: builtins.length (targetsForHex tos hx) > 1) present;
    in
    if unswappable != [ ] then
      throw "theme-runtime (${label}): ${toString unswappable} not build-variant token hex(es); surface would ship untranslated"
    else if ambiguous != [ ] then
      throw "theme-runtime (${label}): ${toString ambiguous} map to >1 target hex; surface hex swap is ambiguous"
    else
      text;

  # A checked textual recolour: assert, then replaceStrings.
  recolorWith =
    label: tos: text:
    builtins.replaceStrings buildHexes tos (assertRecolorable label tos text);

  swapToOther = recolorWith "jylhis ${buildVariant}->${otherVariant}" (hexesFor otherVariant);

  # Applied to mako/waybar/gtk; swapShade is a no-op on the first two (they
  # carry no shade literal), so a uniform path is safe.
  textFor =
    v: text:
    if v == buildVariant then text else swapShade palettes.${otherVariant}.hex.text (swapToOther text);

  # Resolved single-variant sources to translate. Both are marchyo-owned
  # (Stylix targets disabled in modules/generic/theme.nix), so every color in
  # them is a semantic-token hex. If a consumer overrides waybar's style with
  # a path instead of a string, that surface is left build-time.
  makoText =
    if config.services.mako.enable && config.xdg.configFile ? "mako/config" then
      config.xdg.configFile."mako/config".text
    else
      null;
  waybarStyle =
    if config.programs.waybar.enable && lib.isString config.programs.waybar.style then
      config.programs.waybar.style
    else
      null;

  # Resolved GTK user CSS (what HM installs as gtk-3.0/gtk.css). Design 3.0.0
  # supplies per-polarity stylesheets (no .dark custom-prop block, no
  # light-baked top level), so the resolved text is already valid for both
  # GTK3 and GTK4 and translating it to another theme is the same
  # semantic-token hex swap mako/waybar use below. Consumers overriding
  # gtk.gtk3.extraCss to "" leave this surface build-time.
  gtkCss =
    if config.xdg.configFile ? "gtk-3.0/gtk.css" then
      config.xdg.configFile."gtk-3.0/gtk.css".text
    else
      null;

  # Resolved bat config (modules/home/bat.nix writes `--theme=jylhis-<variant>`
  # plus non-theme lines like --map-syntax). bat resolves a theme by its cache
  # entry's filename stem, so a runtime switch is a `--theme=` line swap: take
  # the build config text and repoint only that line per target theme, leaving
  # every other line intact. The two possible build values are the Jylhis pair,
  # so swapping both covers either build variant. Each theme's tmTheme must be
  # in bat's cache: the Jylhis pair ships in pkgs.jylhis-themes (installed by
  # bat.nix); scheme/inline tmThemes are generated and registered via
  # programs.bat.themes below so `bat cache --build` picks them up at activation.
  batConfig =
    if config.programs.bat.enable or false && config.xdg.configFile ? "bat/config" then
      config.xdg.configFile."bat/config".text
    else
      null;
  batConfigWithTheme =
    themeName:
    builtins.replaceStrings
      [ "--theme=jylhis-dark" "--theme=jylhis-light" ]
      [ "--theme=${themeName}" "--theme=${themeName}" ]
      batConfig;
  batTmTheme = import ../../lib/base16-tmtheme.nix { inherit lib; };

  wallpaperCfg = themeCfg.wallpaper or { };
  wallpaperEnabled = wallpaperCfg.enable or true;
  wallpaperPackage = wallpaperCfg.package or pkgs.marchyo-wallpapers;

  # Hyprland color keywords — mirrors the values modules/home/hyprland.nix
  # bakes into the build-time config (misc:background_color +
  # general:col.{active,inactive}_border).
  rgb = h: "rgb(${lib.removePrefix "#" h})";
  rgba = h: a: "rgba(${lib.removePrefix "#" h}${a})";
  hyprlandKeywordsFor = v: ''
    misc:background_color ${rgb palettes.${v}.hex.bg}
    general:col.active_border ${rgba palettes.${v}.hex.accent "ff"}
    general:col.inactive_border ${rgba palettes.${v}.hex."border-strong" "ff"}
  '';

  ghosttyThemeFor = v: if v == "dark" then "jylhis-dark" else "jylhis-light";

  # Ghostty theme pair (`theme = dark:…,light:…`): ghostty subscribes to the
  # system color-scheme via the xdg-desktop-portal and restyles open windows
  # live when the CLI flips the dconf key. Both themes are always installed
  # (modules/home/ghostty.nix).
  ghosttyThemePair = "dark:${ghosttyThemeFor "dark"},light:${ghosttyThemeFor "light"}";

  themeDirFor =
    v:
    pkgs.linkFarm "marchyo-theme-${v}" (
      {
        variant = pkgs.writeText "marchyo-theme-${v}-variant" "${v}\n";
        "colors.json" = pkgs.writeText "marchyo-theme-${v}-colors.json" (
          colorsJsonFor ("jylhis-" + v) v (jylhisShellColors v)
        );
        "ghostty.conf" = pkgs.writeText "marchyo-theme-${v}-ghostty.conf" ''
          theme = ${ghosttyThemePair}
        '';
        "hyprland.conf" = pkgs.writeText "marchyo-theme-${v}-hyprland.conf" (hyprlandKeywordsFor v);
      }
      // lib.optionalAttrs wallpaperEnabled {
        # Path template mirrors wallpaperFile in modules/home/hyprland.nix.
        "wallpaper.png" = "${wallpaperPackage}/share/marchyo/wallpapers/jylhis-grid-${v}.png";
      }
      // lib.optionalAttrs (makoText != null) {
        "mako.conf" = pkgs.writeText "marchyo-theme-${v}-mako.conf" (textFor v makoText);
      }
      // lib.optionalAttrs (waybarStyle != null) {
        "waybar.css" = pkgs.writeText "marchyo-theme-${v}-waybar.css" (textFor v waybarStyle);
      }
      // lib.optionalAttrs (gtkCss != null) {
        "gtk.css" = pkgs.writeText "marchyo-theme-${v}-gtk.css" (textFor v gtkCss);
      }
      // lib.optionalAttrs (batConfig != null) {
        "bat.conf" = pkgs.writeText "marchyo-theme-${v}-bat.conf" (batConfigWithTheme "jylhis-${v}");
      }
    );

  themeDirs = {
    dark = themeDirFor "dark";
    light = themeDirFor "light";
  };

  # Beyond the always-built Jylhis pair, any tinted-schemes catalog scheme can
  # be listed for runtime switching. Its assets translate the build variant's
  # resolved surfaces from semantic-token hexes to the scheme's base16 slots,
  # via the same token/slot correspondence jylhis-palette.nix uses for Stylix.
  loadScheme = import ../generic/base16-scheme.nix {
    schemes = pkgs.tinted-schemes-src;
    inherit lib;
  };

  # kebab-case token -> camelCase, shared with the Color.qml generator in
  # packages/marchyo-shell/package.nix so colors.json keys and generated
  # Color.qml property names can never drift apart.
  toCamel = import ../../lib/camel-case.nix { inherit lib; };

  # Palette subset the shell's Color.qml exposes (semantic tokens minus the
  # syntax-highlighting ones — same filter package.nix applies), camelCased.
  shellTokenNames = lib.filter (n: !lib.hasPrefix "syn-" n) tokenNames;
  jylhisShellColors =
    v: lib.listToAttrs (map (n: lib.nameValuePair (toCamel n) palettes.${v}.hex.${n}) shellTokenNames);
  schemeShellColors =
    scheme:
    lib.listToAttrs (
      map (n: lib.nameValuePair (toCamel n) (schemeHexForToken scheme n)) shellTokenNames
    );
  colorsJsonFor =
    name: variant: colors:
    builtins.toJSON { inherit name variant colors; };

  # Token → base16 slot. The 16 exported pairs mirror jylhis-palette.nix's
  # base16 attrset; the extras get the closest slot by role, which for a tinted
  # scheme is lossy (border/syn-comment collapse onto text-faint's base03,
  # accent-hover onto accent's base09, accent-subtle onto bg-subtle's base01).
  # The jylhis light/dark swap never uses this table — swapToOther is exact per
  # token. `cursor` must share accent's slot: it is the same hex as accent, so
  # without it the (unused) cursor token would map a shared surface hex (#f5a351
  # / #693900) to two targets and trip assertRecolorable. Any token still absent
  # from this table keeps its build-variant hex (identity); keep this in lockstep
  # with TOKEN_SLOTS in packages/marchyo-cli/packages/core/src/matugen.ts.
  tokenSlots = {
    bg = "base00";
    "bg-subtle" = "base01";
    surface = "base02";
    "surface-raised" = "base07";
    "text-faint" = "base03";
    "text-muted" = "base04";
    text = "base05";
    "text-heading" = "base06";
    "status-err" = "base08";
    accent = "base09";
    cursor = "base09";
    "status-warn" = "base0A";
    "syn-string" = "base0B";
    "syn-type" = "base0C";
    "status-info" = "base0D";
    "syn-keyword" = "base0E";
    brand = "base0F";
    border = "base03";
    "border-strong" = "base04";
    "accent-hover" = "base09";
    "accent-subtle" = "base01";
    "status-ok" = "base0B";
    "syn-comment" = "base03";
  };

  schemeHexForToken =
    scheme: n:
    if tokenSlots ? ${n} then scheme.slots.${tokenSlots.${n}} else palettes.${buildVariant}.hex.${n};
  swapToScheme =
    scheme: recolorWith "scheme ${scheme.name}" (map (schemeHexForToken scheme) tokenNames);
  # gtk also carries the shade literal; map it to the scheme's text (base05).
  swapGtkToScheme = scheme: text: swapShade scheme.slots.base05 (swapToScheme scheme text);

  schemeHyprlandKeywords = scheme: ''
    misc:background_color ${rgb scheme.slots.base00}
    general:col.active_border ${rgba scheme.slots.base09 "ff"}
    general:col.inactive_border ${rgba scheme.slots.base04 "ff"}
  '';

  # Inline terminal colors (base16's standard ANSI mapping) — base16 themes
  # have no named ghostty theme to reference.
  schemeGhosttyConf =
    scheme:
    let
      s = scheme.slots;
      ansi = [
        s.base00
        s.base08
        s.base0B
        s.base0A
        s.base0D
        s.base0E
        s.base0C
        s.base05
        s.base03
        s.base08
        s.base0B
        s.base0A
        s.base0D
        s.base0E
        s.base0C
        s.base07
      ];
    in
    ''
      background = ${s.base00}
      foreground = ${s.base05}
      cursor-color = ${s.base05}
      selection-background = ${s.base02}
      selection-foreground = ${s.base05}
    ''
    + lib.concatImapStrings (i: c: "palette = ${toString (i - 1)}=${c}\n") ansi;

  mkSchemeThemeDir =
    scheme:
    pkgs.linkFarm "marchyo-theme-${scheme.name}" (
      {
        variant = pkgs.writeText "marchyo-theme-${scheme.name}-variant" "${scheme.variant}\n";
        "colors.json" = pkgs.writeText "marchyo-theme-${scheme.name}-colors.json" (
          colorsJsonFor scheme.name scheme.variant (schemeShellColors scheme)
        );
        "ghostty.conf" = pkgs.writeText "marchyo-theme-${scheme.name}-ghostty.conf" (
          schemeGhosttyConf scheme
        );
        "hyprland.conf" = pkgs.writeText "marchyo-theme-${scheme.name}-hyprland.conf" (
          schemeHyprlandKeywords scheme
        );
      }
      // lib.optionalAttrs wallpaperEnabled {
        # A per-theme wallpaper when the entry supplies one, else reuse the
        # Jylhis grid of matching polarity so the background tracks dark/light.
        "wallpaper.png" =
          if (scheme.wallpaper or null) != null then
            scheme.wallpaper
          else
            "${wallpaperPackage}/share/marchyo/wallpapers/jylhis-grid-${scheme.variant}.png";
      }
      // lib.optionalAttrs (makoText != null) {
        "mako.conf" = pkgs.writeText "marchyo-theme-${scheme.name}-mako.conf" (
          swapToScheme scheme makoText
        );
      }
      // lib.optionalAttrs (waybarStyle != null) {
        "waybar.css" = pkgs.writeText "marchyo-theme-${scheme.name}-waybar.css" (
          swapToScheme scheme waybarStyle
        );
      }
      // lib.optionalAttrs (gtkCss != null) {
        "gtk.css" = pkgs.writeText "marchyo-theme-${scheme.name}-gtk.css" (swapGtkToScheme scheme gtkCss);
      }
      // lib.optionalAttrs (batConfig != null) {
        "bat.conf" = pkgs.writeText "marchyo-theme-${scheme.name}-bat.conf" (
          batConfigWithTheme scheme.name
        );
      }
    );

  themeList =
    themeCfg.themes or [
      "jylhis-dark"
      "jylhis-light"
    ];
  # An entry is either a name (the Jylhis pair, or a tinted-schemes base16
  # name) or an inline base16 theme `{ name; variant; slots; wallpaper?; }`.
  # Inline entries share the exact shape mkSchemeThemeDir consumes, so they
  # need no extra machinery.
  resolveTheme =
    entry:
    if lib.isString entry then
      if entry == "jylhis-dark" then
        {
          name = entry;
          variant = "dark";
          dir = themeDirs.dark;
          scheme = null;
        }
      else if entry == "jylhis-light" then
        {
          name = entry;
          variant = "light";
          dir = themeDirs.light;
          scheme = null;
        }
      else
        let
          scheme = loadScheme entry;
        in
        {
          inherit (scheme) name variant;
          dir = mkSchemeThemeDir scheme;
          inherit scheme;
        }
    else
      {
        inherit (entry) name variant;
        dir = mkSchemeThemeDir entry;
        scheme = entry;
      };
  resolvedThemes = map resolveTheme themeList;

  # base16 scheme/inline themes have no shipped bat tmTheme; generate one per
  # scheme and register it so bat.nix's activation `bat cache --build` compiles
  # it into the theme cache. The Jylhis pair (scheme == null) already ships its
  # tmThemes via bat.nix. Keyed by theme name = bat filename stem = the
  # `--theme=` value each scheme dir's bat.conf points at.
  schemeBatThemes = lib.listToAttrs (
    map (
      t:
      lib.nameValuePair t.name {
        # The HM bat `themes` submodule takes { src; file?; }: a bare src file
        # installs verbatim (file defaults to null). Generate the tmTheme to a
        # store file rather than passing the deprecated string form.
        src = pkgs.writeText "${t.name}.tmTheme" (batTmTheme {
          inherit (t.scheme) name slots;
        });
      }
    ) (lib.filter (t: t.scheme != null) resolvedThemes)
  );

  manifest = builtins.toJSON (
    map (t: {
      inherit (t) name variant;
      dir = "${t.dir}";
    }) resolvedThemes
  );

in
{
  config = lib.mkIf (desktopEnabled && themeEnabled) {
    # matugen backs `marchyo theme generate <image>`: turns an image into a
    # base16 palette, then materializes a runtime theme dir from the result.
    home.packages = [ pkgs.matugen ];

    # Register generated base16 tmThemes so bat.nix's `bat cache --build`
    # compiles them into the theme cache; the per-theme bat.conf then selects
    # one by name at runtime (relinked into ~/.config/bat/config, below).
    programs.bat.themes = schemeBatThemes;

    # `marchyo theme set/next` repoints HM-managed symlinks at theme dirs
    # (activateThemeDir in the CLI), and `theme generate` points the pointer
    # at the CLI-owned matugen dir in state. HM's collision check treats any
    # such link as foreign, and neither backupFileExtension nor backupCommand
    # applies (both require a regular file), so activation fails with "would
    # be clobbered" until the links are removed by hand. Restore them to
    # unmanaged state just before the collision check; linkGeneration below
    # then re-creates them declaratively — exactly the ephemeral-overlay
    # reset documented at the top of this module. Only links whose readlink
    # target is a marchyo theme location are touched; real files fall
    # through to the regular backup path. A *foreign* symlink on one of these
    # paths (target matching neither pattern — e.g. one a user or another tool
    # created) is deliberately left in place, so activation then aborts with
    # "would be clobbered" until it is removed by hand; we do not delete links
    # we did not create.
    home.activation.resetThemeRuntimeSurfaces = lib.hm.dag.entryBefore [ "checkLinkTargets" ] (
      let
        runtimeSurfaces = [
          "${config.xdg.configHome}/gtk-3.0/gtk.css"
          "${config.xdg.configHome}/gtk-4.0/gtk.css"
          "${config.xdg.configHome}/mako/config"
          "${config.xdg.configHome}/waybar/style.css"
          "${config.xdg.configHome}/bat/config"
          "${config.xdg.configHome}/marchyo/current-theme"
        ];
      in
      ''
        for p in ${lib.concatStringsSep " " (map lib.escapeShellArg runtimeSurfaces)}; do
          if [ -L "$p" ]; then
            case "$(readlink "$p")" in
              *-marchyo-theme-*|${lib.escapeShellArg "${config.xdg.stateHome}/marchyo/generated-theme"}*) rm -f -- "$p" ;;
            esac
          fi
        done
      ''
    );

    # Pointer to the active variant's assets; the CLI repoints it (ln -sfn) at runtime.
    xdg.configFile."marchyo/current-theme".source = themeDirs.${buildVariant};

    # Manifest for the CLI (`marchyo theme list/set/next`). Listing the dirs
    # also roots them in the profile closure, so switching stays a symlink swap.
    xdg.dataFile."marchyo/themes/manifest.json".text = manifest;

    # Optional (`?`) include: ghostty processes config-file includes after the
    # main file, so this `theme` overrides the build-time one (ghostty.nix).
    programs.ghostty.settings.config-file = "?${config.xdg.configHome}/marchyo/current-theme/ghostty.conf";
  };
}
