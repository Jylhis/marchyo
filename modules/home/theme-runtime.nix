# Runtime theme switching, build-time asset layer.
#
# The declarative build-time variant (marchyo.theme.variant) stays the source
# of truth; this module additionally materializes every theme in
# marchyo.theme.themes as runtime-swappable asset dirs plus a manifest the
# `marchyo theme` CLI reads. The switch is an ephemeral overlay: the next
# activation resets every surface (and ~/.config/marchyo/current-theme) back
# to the declarative default. bat, fzf, starship, hyprlock, console, k9s,
# lazygit, spotify-player and gdu have runtime emitters too; Qt follows the GTK
# relink; plymouth and ncspot (whose theme sits inline in config.toml, with no
# include) stay on the build-time default until rebuild.
#
# The dual-variant mako/waybar/gtk sources are derived from the resolved Home
# Manager config by translating the build variant's semantic-token hexes to
# the other variant's, so edits to those modules flow into both variants
# automatically. ANSI hexes are excluded (several collide with semantic tokens
# but map differently, and don't appear in these surfaces).
#
# Every theme dir also ships palette.json (token -> hex plus token -> base16
# slot), and the build-variant dir ships templates/ with the same three
# surfaces as placeholders, which `marchyo theme generate` fills from a
# matugen palette. The generators shared with the CLI live in
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

  # Resolved single-variant sources to translate. Both are marchyo-owned (no
  # Stylix), so every color in them is a semantic-token hex. If a consumer
  # overrides waybar's style with a path instead of a string, that surface is
  # left build-time.
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
  templateFor =
    label: text:
    builtins.replaceStrings [ (shadeRgba palettes.${buildVariant}.hex.text) ] [ "{{shade}}" ] (
      builtins.replaceStrings buildHexes (map (n: "{{token:${n}}}") tokenNames) (
        assertRecolorable "template ${label}" templateSlotTos text
      )
    );
  templateFiles =
    lib.optionalAttrs (makoText != null) {
      "templates/mako.conf" = pkgs.writeText "marchyo-theme-template-mako.conf" (
        templateFor "mako" makoText
      );
    }
    // lib.optionalAttrs (waybarStyle != null) {
      "templates/waybar.css" = pkgs.writeText "marchyo-theme-template-waybar.css" (
        templateFor "waybar" waybarStyle
      );
    }
    // lib.optionalAttrs (gtkCss != null) {
      "templates/gtk.css" = pkgs.writeText "marchyo-theme-template-gtk.css" (templateFor "gtk" gtkCss);
    };

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

  # Token -> base16 slot lives in lib/theme-generators.nix (gen.tokenSlots);
  # the jylhis light/dark swap never uses it, swapToOther is exact per token.
  schemeHexForToken = scheme: gen.slotResolver scheme.slots palettes.${buildVariant}.hex;
  swapToScheme =
    scheme: recolorWith "scheme ${scheme.name}" (map (schemeHexForToken scheme) tokenNames);
  # gtk also carries the shade literal; map it to the scheme's text (base05).
  swapGtkToScheme = scheme: text: swapShade scheme.slots.base05 (swapToScheme scheme text);

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

  manifest = builtins.toJSON {
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
          "${config.xdg.configHome}/mako/config"
          "${config.xdg.configHome}/waybar/style.css"
          "${config.xdg.configHome}/bat/config"
          "${config.xdg.configHome}/k9s/skins/jylhis.yaml"
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

    # Manifest for the CLI (`marchyo theme list/set/next`, and `bg` reads
    # followWallpaper from it). Listing the dirs also roots them in the
    # profile closure, so switching stays a symlink swap.
    xdg.dataFile."marchyo/themes/manifest.json".text = manifest;

    # Optional (`?`) include: ghostty processes config-file includes after the
    # main file, so this `theme` overrides the build-time one (ghostty.nix).
    programs.ghostty.settings.config-file = "?${config.xdg.configHome}/marchyo/current-theme/ghostty.conf";
  };
}
