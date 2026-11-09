# Runtime theme switching, build-time asset layer.
#
# The declarative build-time variant (marchyo.theme.variant) supplies the
# default; this module additionally materializes every theme in
# marchyo.theme.themes as runtime-swappable asset dirs plus a manifest the
# `marchyo theme` CLI reads. The switch is an overlay on the declarative
# default: every activation first resets the relinked surfaces (and
# ~/.config/marchyo/current-theme) to the build-time state, then replays the
# stored runtime overrides with `marchyo runtime restore`. bat, fzf, starship,
# hyprlock, console, k9s, lazygit, spotify-player, gdu, tmux, fcitx5, btop,
# kitty, foot, alacritty, helix, neovim and emacs have runtime emitters too; Qt follows the
# GTK relink; plymouth stays on the build-time default until rebuild, and the
# Chromium policy is root-owned, so it carries the build-time colour only.
#
# The dual-variant gtk source is derived from the resolved Home Manager config
# by translating the build variant's semantic-token hexes to the other
# variant's, so edits to that module flow into both variants automatically.
# ANSI hexes are excluded (several collide with semantic tokens but map
# differently, and don't appear in this surface).
#
# Every theme dir also ships palette.json (token -> hex plus token -> base16
# slot), a wallpapers/ dir (the theme's own
# wallpapers beside the default wallpaper.png), and the build-variant dir ships
# templates/ with the same surfaces as placeholders, which `marchyo theme
# generate` fills from a matugen palette. The generators shared with the CLI live in
# lib/theme-generators.nix.
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
  cliEnabled = (osConfig.marchyo or { }).cli.enable or false;
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
  # generated gtk css carries `rgba(<text rgb>, 0.08)`.
  # Translate it to the target palette's text rgb alongside the hex swap — for
  # the jylhis other variant (textFor) and every base16 scheme (swapGtkToScheme).
  gen = import ../../lib/theme-generators.nix { inherit lib; };
  inherit (gen) shadeRgba tokenSlots;
  swapShade =
    targetTextHex:
    builtins.replaceStrings
      [ (shadeRgba palettes.${buildVariant}.hex.text) ]
      [ (shadeRgba targetTextHex) ];

  # Guard the textual hex swap. `builtins.replaceStrings` applies the first
  # matching `from`, so two tokens that share a build-variant hex but diverge in
  # the target silently miscolour the loser (e.g. status-info and syn-variable
  # are both #005e8a in light); and a colour literal that is not a build-variant
  # token hex (a hardcoded colour, an uppercase/shorthand/8-digit hex, an
  # ANSI-only value) would ship untranslated. Both fail the build here. Scoped
  # to the hexes a surface actually carries, so an unused collision elsewhere in
  # the palette is never a false positive.
  #
  # A colour literal is a `#` hex run whose following char is not an identifier
  # char, so a CSS id selector (`#cpu`, `#battery`) — a `#` run butting
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

  # Fill a {{token:<name>}} / {{shade}} template from a token resolver. Every
  # placeholder names a token, so this never maps a hex back to a role: two
  # tokens that share a hex in one variant and split in another (ink is text,
  # rule and link by day) still fill correctly.
  fillTemplate =
    resolve: text:
    lib.concatMapStrings (
      part:
      if builtins.isString part then
        part
      else if builtins.head part == "shade" then
        shadeRgba (resolve "text")
      else
        resolve (builtins.elemAt part 1)
    ) (builtins.split "[{][{](shade|token:([a-z0-9-]+))[}][}]" text);

  # The design ships each GTK sheet and the same sheet as a template
  # (platforms/gtk/jylhis.css.in). When the resolved GTK CSS carries the
  # design's build-variant sheet (the default, see jylhis-theme.nix), that
  # part becomes the template and only the text around it (a consumer's own
  # extraCss) goes through the guarded hex swap. A consumer who replaced the
  # sheet keeps the swap for the whole text.
  designGtk = name: builtins.readFile "${pkgs.jylhis-design-src}/platforms/gtk/${name}";
  designSheet = designGtk "jylhis-${buildVariant}.css";
  hexTemplate =
    label: text:
    builtins.replaceStrings [ (shadeRgba palettes.${buildVariant}.hex.text) ] [ "{{shade}}" ] (
      builtins.replaceStrings buildHexes (map (n: "{{token:${n}}}") tokenNames) (
        assertRecolorable "template ${label}" templateSlotTos text
      )
    );
  gtkTemplate =
    let
      parts = lib.splitString designSheet gtkCss;
    in
    if gtkCss != null && builtins.length parts == 2 then
      hexTemplate "gtk prefix" (builtins.head parts)
      + designGtk "jylhis.css.in"
      + hexTemplate "gtk suffix" (builtins.elemAt parts 1)
    else
      null;

  textFor =
    v: text:
    if v == buildVariant then text else swapShade palettes.${otherVariant}.hex.text (swapToOther text);
  gtkFor =
    v:
    if v == buildVariant then
      gtkCss
    else if gtkTemplate != null then
      fillTemplate (jylhisResolve v) gtkTemplate
    else
      textFor v gtkCss;

  # Resolved GTK user CSS (what HM installs as gtk-3.0/gtk.css). Design 3.0.0
  # supplies per-polarity stylesheets (no .dark custom-prop block, no
  # light-baked top level), so the resolved text is already valid for both
  # GTK3 and GTK4 and translating it to another theme is a semantic-token hex
  # swap. Consumers overriding gtk.gtk3.extraCss to "" leave this surface
  # build-time.
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
  batTmTheme = gen.tmTheme;

  wallpaperCfg = themeCfg.wallpaper or { };
  wallpaperEnabled = wallpaperCfg.enable or true;
  wallpaperPackage = wallpaperCfg.package or pkgs.marchyo-wallpapers;

  # Hyprland color keywords: mirrors the values modules/home/hyprland.nix
  # bakes into the build-time config (misc:background_color +
  # general:col.{active,inactive}_border).
  jylhisResolve = v: t: palettes.${v}.hex.${t};
  hyprlandKeywordsFor = v: gen.hyprlandKeywordsFor (jylhisResolve v);

  ghosttyThemeFor = v: if v == "dark" then "jylhis-dark" else "jylhis-light";

  # Ghostty theme pair (`theme = dark:…,light:…`): ghostty subscribes to the
  # system color-scheme via the xdg-desktop-portal and restyles open windows
  # live when the CLI flips the dconf key. Both themes are always installed
  # (modules/home/ghostty.nix).
  ghosttyThemePair = "dark:${ghosttyThemeFor "dark"},light:${ghosttyThemeFor "light"}";

  # fzf `--color` string (gen.fzfOptsText), emitted per theme as `fzf.opts`
  # and read live via FZF_DEFAULT_OPTS_FILE (set in the config block): fzf
  # reads the file before FZF_DEFAULT_OPTS, and the pointer path is stable, so
  # repointing current-theme recolours every new fzf launch (including from
  # already-open shells) with no re-login.
  fzfOptsForJylhis = v: gen.fzfOptsText (jylhisResolve v) palettes.${v}.ansi.green;

  # hyprlock colour include (gen.hyprlockVarsFor). hyprlock reads its config
  # afresh at each lock and the source path is the stable current-theme
  # pointer, so the next lock uses the current theme with no reload.
  # Geometry/fontScale stay build-time in hyprlock.nix; only colours move here.
  hyprlockColorsFor = v: gen.hyprlockVarsFor (jylhisResolve v);

  # setvtrgb(8) palette table emitted per theme as `console.txt`. Applying it to
  # live VTs needs setvtrgb against the console device, which the CLI attempts
  # best-effort; otherwise the console tracks the declarative console.colors
  # (modules/nixos/console.nix) at the next boot.
  consoleTableFrom16 = gen.consoleTable;

  # Base16-slot TUI surfaces (lib/theme-generators.nix): k9s skin, lazygit
  # gui.theme overlay, spotify-player theme.toml and gdu.yaml. The app
  # modules link to (or, for lazygit, list via LG_CONFIG_FILE) these files
  # under the current-theme pointer. Shared by the Jylhis pair (slots from
  # jylhisSlots) and every scheme dir.
  slotSurfaceFiles = label: slots: {
    "k9s-skin.yaml" = pkgs.writeText "marchyo-theme-${label}-k9s-skin.yaml" (gen.k9sSkinText slots);
    "lazygit.yml" = pkgs.writeText "marchyo-theme-${label}-lazygit.yml" (gen.lazygitText slots);
    "spotify-player-theme.toml" = pkgs.writeText "marchyo-theme-${label}-spotify-player-theme.toml" (
      gen.spotifyPlayerThemeText slots
    );
    "gdu.yaml" = pkgs.writeText "marchyo-theme-${label}-gdu.yaml" (gen.gduText slots);
  };
  # Application surfaces (tmux, fcitx5) from the same slots; both read them
  # through the current-theme pointer.
  appSurfaceFiles =
    label: slots:
    lib.mapAttrs (name: text: pkgs.writeText "marchyo-theme-${label}-${name}" text) (
      gen.appSurfaceTexts slots
    );
  # Terminal and editor surfaces (btop, kitty, foot, alacritty, helix, neovim,
  # emacs) from the same slots; lib/theme-surfaces.nix.
  surfaces = import ../../lib/theme-surfaces.nix { inherit lib gen; };
  editorSurfaceFiles =
    label: slots:
    lib.mapAttrs (name: text: pkgs.writeText "marchyo-theme-${label}-${name}" text) (
      surfaces.texts slots
    );

  # wallpapers/: store symlinks named by the file's own name (a bare store path
  # carries its hash as the name prefix).
  wallpaperLinks =
    paths:
    lib.listToAttrs (
      map (
        p:
        let
          str = toString p;
          base = baseNameOf str;
        in
        lib.nameValuePair (builtins.unsafeDiscardStringContext (
          if dirOf str == builtins.storeDir then builtins.substring 33 (-1) base else base
        )) p
      ) paths
    );
  wallpapersDirFor =
    label: paths: pkgs.linkFarm "marchyo-theme-${label}-wallpapers" (wallpaperLinks paths);
  # The Jylhis pair lists the generated patterns beside the default grid.
  packageWallpapers =
    v:
    lib.filter (p: !lib.hasSuffix "jylhis-grid-${v}.png" p) (
      (wallpaperPackage.forPolarity or (_: [ ])) v
    );

  # The build-variant dir is the declarative state, so it carries the slots
  # the build-time modules use (marchyo.theme.scheme when set); the other
  # variant carries the Jylhis pair's own slots.
  jylhisSlots =
    v:
    import ../generic/theme-slots.nix {
      inherit pkgs lib;
      variant = v;
      scheme = if v == buildVariant then themeCfg.scheme or null else null;
    };

  # palette.json: the full kebab-case token -> hex map (syn-* included) plus
  # the token -> base16 slot table. `marchyo theme generate` resolves tokens
  # through these slots and falls back to the build dir's hex for a token
  # without a slot.
  paletteJsonFor = tokens: builtins.toJSON { inherit tokens tokenSlots; };

  # Build-variant surface templates for `marchyo theme generate`: the resolved
  # HM text with each build hex replaced by `{{token:<name>}}` and the gtk
  # shade literal by `{{shade}}`. The guard resolves each token to its slot (or
  # its own build hex when it has none), so every token sharing a build hex
  # fills identically and the first token name per hex is a safe placeholder.
  templateSlotTos = map (n: tokenSlots.${n} or palettes.${buildVariant}.hex.${n}) tokenNames;
  templateFiles =
    lib.optionalAttrs (gtkCss != null) {
      "templates/gtk.css" = pkgs.writeText "marchyo-theme-template-gtk.css" (
        if gtkTemplate != null then gtkTemplate else hexTemplate "gtk" gtkCss
      );
    }
    // lib.mapAttrs' (
      name: text:
      lib.nameValuePair "templates/${name}" (pkgs.writeText "marchyo-theme-template-${name}" text)
    ) surfaces.templates;

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
      // lib.optionalAttrs (gtkCss != null) {
        "gtk.css" = pkgs.writeText "marchyo-theme-${v}-gtk.css" (gtkFor v);
      }
      // lib.optionalAttrs (batConfig != null) {
        "bat.conf" = pkgs.writeText "marchyo-theme-${v}-bat.conf" (batConfigWithTheme "jylhis-${v}");
      }
      // {
        "fzf.opts" = pkgs.writeText "marchyo-theme-${v}-fzf.opts" (fzfOptsForJylhis v);
      }
      // {
        "hyprlock-colors.conf" = pkgs.writeText "marchyo-theme-${v}-hyprlock-colors.conf" (
          hyprlockColorsFor v
        );
      }
      // {
        "console.txt" = pkgs.writeText "marchyo-theme-${v}-console.txt" (
          consoleTableFrom16 palettes.${v}.tty16
        );
        "palette.json" = pkgs.writeText "marchyo-theme-${v}-palette.json" (
          paletteJsonFor palettes.${v}.hex
        );
      }
      // slotSurfaceFiles v (jylhisSlots v)
      // appSurfaceFiles v (jylhisSlots v)
      // editorSurfaceFiles v (jylhisSlots v)
      // {
        wallpapers = wallpapersDirFor v (lib.optionals wallpaperEnabled (packageWallpapers v));
      }
      // lib.optionalAttrs (v == buildVariant) templateFiles
    );

  themeDirs = {
    dark = themeDirFor "dark";
    light = themeDirFor "light";
  };

  # Beyond the always-built Jylhis pair, any tinted-schemes catalog scheme can
  # be listed for runtime switching. Its assets translate the build variant's
  # resolved surfaces from semantic-token hexes to the scheme's base16 slots,
  # via the same token/slot correspondence jylhis-palette.nix uses for base16.
  loadScheme = import ../generic/base16-scheme.nix {
    schemes = pkgs.tinted-schemes-src;
    inherit lib;
  };

  # kebab-case token -> camelCase, shared with the Colors.qml generator in
  # packages/marchyo-shell/package.nix so colors.json keys and generated
  # Colors.qml property names can never drift apart.
  toCamel = lib.toCamelCase;

  # Palette subset the shell's Colors.qml exposes (semantic tokens minus the
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

  # Token -> base16 slot lives in lib/theme-generators.nix (gen.tokenSlots);
  # the jylhis light/dark swap never uses it, swapToOther is exact per token.
  schemeHexForToken = scheme: gen.slotResolver scheme.slots palettes.${buildVariant}.hex;
  swapToScheme =
    scheme: recolorWith "scheme ${scheme.name}" (map (schemeHexForToken scheme) tokenNames);
  # gtk also carries the shade literal; map it to the scheme's text (base05).
  swapGtkToScheme =
    scheme: text:
    if gtkTemplate != null then
      fillTemplate (schemeHexForToken scheme) gtkTemplate
    else
      swapShade scheme.slots.base05 (swapToScheme scheme text);

  fzfOptsForScheme = scheme: gen.fzfOptsText (schemeHexForToken scheme) scheme.slots.base0B;
  hyprlockColorsForScheme = scheme: gen.hyprlockVarsFor (schemeHexForToken scheme);
  schemeTty16 = scheme: gen.tty16FromSlots scheme.slots;
  schemeHyprlandKeywords = scheme: gen.hyprlandKeywordsFor (schemeHexForToken scheme);
  schemeGhosttyConf = scheme: gen.ghosttyConfFromSlots scheme.slots;
  schemePaletteJson = scheme: paletteJsonFor (lib.genAttrs tokenNames (schemeHexForToken scheme));

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
      // lib.optionalAttrs (gtkCss != null) {
        "gtk.css" = pkgs.writeText "marchyo-theme-${scheme.name}-gtk.css" (swapGtkToScheme scheme gtkCss);
      }
      // lib.optionalAttrs (batConfig != null) {
        "bat.conf" = pkgs.writeText "marchyo-theme-${scheme.name}-bat.conf" (
          batConfigWithTheme scheme.name
        );
      }
      // {
        "fzf.opts" = pkgs.writeText "marchyo-theme-${scheme.name}-fzf.opts" (fzfOptsForScheme scheme);
      }
      // {
        "console.txt" = pkgs.writeText "marchyo-theme-${scheme.name}-console.txt" (
          consoleTableFrom16 (schemeTty16 scheme)
        );
      }
      // {
        "hyprlock-colors.conf" = pkgs.writeText "marchyo-theme-${scheme.name}-hyprlock-colors.conf" (
          hyprlockColorsForScheme scheme
        );
        "palette.json" = pkgs.writeText "marchyo-theme-${scheme.name}-palette.json" (
          schemePaletteJson scheme
        );
      }
      // slotSurfaceFiles scheme.name scheme.slots
      // appSurfaceFiles scheme.name scheme.slots
      // editorSurfaceFiles scheme.name scheme.slots
      // {
        wallpapers = wallpapersDirFor scheme.name (
          lib.optionals wallpaperEnabled (scheme.wallpapers or [ ])
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

  fcitx5Glyphs = [
    "arrow"
    "next"
    "prev"
    "radio"
  ];

  manifest = builtins.toJSON {
    defaultTheme = {
      name = "jylhis-${buildVariant}";
      variant = buildVariant;
      dir = "${themeDirs.${buildVariant}}";
    };
    themes = map (t: {
      inherit (t) name variant;
      dir = "${t.dir}";
    }) resolvedThemes;
    followWallpaper = themeCfg.followWallpaper or false;
  };

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

    # fzf reads its `--color` from this file (before FZF_DEFAULT_OPTS) at every
    # launch. The path is the stable current-theme pointer, so `marchyo theme
    # set/next` recolours new fzf runs live with no re-login; fzf.nix drops its
    # build-time `programs.fzf.colors` on desktop so this file wins. The theme
    # dir always ships fzf.opts, so the file is never missing.
    home.sessionVariables.FZF_DEFAULT_OPTS_FILE = "${config.xdg.configHome}/marchyo/current-theme/fzf.opts";

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
          # tests/cli/theme-surfaces-test.js keeps this list a superset of
          # what the CLI relinks.
          "${config.xdg.configHome}/bat/config"
          "${config.xdg.configHome}/k9s/skins/jylhis.yaml"
          "${config.xdg.configHome}/btop/themes/marchyo.theme"
          "${config.xdg.configHome}/kitty/marchyo-theme.conf"
          "${config.xdg.configHome}/foot/marchyo-theme.ini"
          "${config.xdg.configHome}/alacritty/marchyo-theme.toml"
          "${config.xdg.configHome}/helix/themes/marchyo.toml"
          "${config.xdg.dataHome}/nvim/site/colors/marchyo.lua"
          "${config.xdg.configHome}/marchyo/current-theme"
        ];
      in
      ''
        for p in ${lib.concatStringsSep " " (map lib.escapeShellArg runtimeSurfaces)}; do
          if [ -L "$p" ]; then
            case "$(readlink "$p")" in
              *-marchyo-theme-*|${lib.escapeShellArg "${config.xdg.stateHome}/marchyo/generated-theme"}*) run rm -f -- "$p" ;;
            esac
          fi
        done
      ''
    );

    # Replay the stored runtime overrides once the declarative state is back in
    # place. Best effort: it never fails the activation. An activation has no
    # session environment, so the running Hyprland instance (newest live
    # socket), the Wayland socket and the user bus come from the runtime dir.
    home.activation.restoreRuntimeOverrides = lib.mkIf cliEnabled (
      lib.hm.dag.entryAfter
        [
          "writeBoundary"
          "linkGeneration"
          "dconfSettings"
          "reloadSystemd"
        ]
        ''
          if [ -z "''${DRY_RUN:-}" ]; then
            rt="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
            if [ -d "$rt/hypr" ]; then
              sig=$(find "$rt/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' |
                sort -rn | while read -r _ name; do
                  if [ -S "$rt/hypr/$name/.socket.sock" ]; then echo "$name"; break; fi
                done)
              [ -z "$sig" ] || export HYPRLAND_INSTANCE_SIGNATURE="$sig"
            fi
            wl=$(find "$rt" -maxdepth 1 -name 'wayland-[0-9]*' -type s -printf '%f\n' 2>/dev/null | sort | head -n 1)
            [ -z "$wl" ] || export WAYLAND_DISPLAY="$wl"
            [ ! -S "$rt/bus" ] || export DBUS_SESSION_BUS_ADDRESS="unix:path=$rt/bus"
            export XDG_RUNTIME_DIR="$rt"
            ${pkgs.coreutils}/bin/timeout 60 ${lib.getExe pkgs.marchyo-cli} runtime restore \
              || echo "marchyo runtime restore failed (ignored)" >&2
          fi
        ''
    );

    # Pointer to the active variant's assets; the CLI repoints it (ln -sfn) at runtime.
    xdg.configFile."marchyo/current-theme".source = themeDirs.${buildVariant};
    # The fcitx5 classicui theme (modules/nixos/fcitx5.nix selects it) reads
    # through the pointer, with the stock glyphs beside it.
    xdg.dataFile = {
      # Manifest for the CLI (`marchyo theme list/set/next`, and `bg` reads
      # followWallpaper from it). Listing the dirs also roots them in the
      # profile closure, so switching stays a symlink swap.
      "marchyo/themes/manifest.json".text = manifest;
      "fcitx5/themes/marchyo/theme.conf".source =
        config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/marchyo/current-theme/fcitx5-theme.conf";
    }
    // lib.genAttrs (map (g: "fcitx5/themes/marchyo/${g}.svg") fcitx5Glyphs) (p: {
      source = "${pkgs.fcitx5}/share/fcitx5/themes/default/${lib.removeSuffix ".svg" (baseNameOf p)}.svg";
    });

    # Optional (`?`) include: ghostty processes config-file includes after the
    # main file, so this `theme` overrides the build-time one (ghostty.nix).
    programs.ghostty.settings.config-file = "?${config.xdg.configHome}/marchyo/current-theme/ghostty.conf";
  };
}
