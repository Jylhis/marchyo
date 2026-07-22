# Runtime theme switching — build-time asset layer.
#
# The declarative build-time variant (marchyo.theme.variant) stays the source
# of truth: this module additionally materializes every theme listed in
# marchyo.theme.themes as runtime-swappable asset dirs plus a manifest the
# `marchyo theme` CLI reads (`theme list/set/next` — the switching logic
# lives in packages/marchyo-cli, which absorbed the old
# marchyo-theme-toggle script). The switch is an ephemeral overlay: the
# next home-manager/NixOS activation resets every surface (and the
# ~/.config/marchyo/current-theme pointer) back to the declarative default.
#
# Live-swapped surfaces: wallpaper (awww), mako, waybar, Hyprland
# border/background colors, and ghostty (new windows / config reload only —
# the `?…/current-theme/ghostty.conf` include below is optional and, per
# ghostty's config-file semantics, processed after the main file so its
# `theme` wins). Everything else (GTK/Qt via Stylix, bat, fzf, starship,
# hyprlock, console, plymouth) stays on the build-time default until rebuild.
#
# The dual-variant mako config and waybar CSS are derived from the *resolved*
# Home Manager config by translating the build variant's semantic-token hexes
# to the other variant's (both palettes come from
# modules/generic/jylhis-palette.nix, i.e. the same tokens.json). This avoids
# duplicating the mako/waybar settings here — future edits to those modules
# flow into both variants automatically. The mapping is well-defined: within
# the semantic tokens (palette/status/syntax) the only shared hex is
# accent == cursor, and those two agree in both variants. The ANSI hexes are
# deliberately excluded from the mapping (several collide with semantic
# tokens while mapping differently, and they don't appear in these surfaces).
{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  themeCfg = (osConfig.marchyo or { }).theme or { };
  themeEnabled = themeCfg.enable or true;
  buildVariant = themeCfg.variant or "dark";
  otherVariant = if buildVariant == "dark" then "light" else "dark";

  mkPalette = variant: import ../generic/jylhis-palette.nix { inherit pkgs lib variant; };
  palettes = {
    dark = mkPalette "dark";
    light = mkPalette "light";
  };

  # Semantic-token hex translation: build variant → other variant.
  tokenNames = lib.attrNames palettes.dark.hex;
  hexesFor = v: map (n: palettes.${v}.hex.${n}) tokenNames;
  swapToOther = builtins.replaceStrings (hexesFor buildVariant) (hexesFor otherVariant);
  textFor = v: text: if v == buildVariant then text else swapToOther text;

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

  ghosttyThemeFor = v: if v == "dark" then "jylhis-roast" else "jylhis-paper";

  themeDirFor =
    v:
    pkgs.linkFarm "marchyo-theme-${v}" (
      {
        variant = pkgs.writeText "marchyo-theme-${v}-variant" "${v}\n";
        "ghostty.conf" = pkgs.writeText "marchyo-theme-${v}-ghostty.conf" ''
          theme = ${ghosttyThemeFor v}
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
    );

  themeDirs = {
    dark = themeDirFor "dark";
    light = themeDirFor "light";
  };

  # ---- N-theme layer (marchyo.theme.themes) --------------------------------
  # Beyond the always-built Jylhis pair, any base16-schemes YAML can be
  # listed for runtime switching. Its assets are derived by translating the
  # build variant's resolved surfaces from semantic-token hexes to the
  # scheme's base16 slots via the same token→slot correspondence
  # jylhis-palette.nix uses to export the Jylhis palette to Stylix.
  loadScheme = import ../generic/base16-scheme.nix { inherit pkgs lib; };

  # Token → base16 slot. The 16 exported pairs mirror jylhis-palette.nix's
  # base16 attrset; the extras (border/hover/subtle/ok/comment) get the
  # closest slot by role. Tokens absent from this table translate to their
  # build-variant hex (identity) — they don't appear in the swapped
  # surfaces (mako/waybar/hyprland keywords, see the grep-audited list).
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
    scheme: builtins.replaceStrings (hexesFor buildVariant) (map (schemeHexForToken scheme) tokenNames);

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
        "ghostty.conf" = pkgs.writeText "marchyo-theme-${scheme.name}-ghostty.conf" (
          schemeGhosttyConf scheme
        );
        "hyprland.conf" = pkgs.writeText "marchyo-theme-${scheme.name}-hyprland.conf" (
          schemeHyprlandKeywords scheme
        );
      }
      // lib.optionalAttrs wallpaperEnabled {
        # No per-scheme art: reuse the Jylhis grid wallpaper of matching
        # polarity so the desktop background at least tracks dark/light.
        "wallpaper.png" = "${wallpaperPackage}/share/marchyo/wallpapers/jylhis-grid-${scheme.variant}.png";
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
    );

  themeList =
    themeCfg.themes or [
      "jylhis-dark"
      "jylhis-light"
    ];
  resolveTheme =
    name:
    if name == "jylhis-dark" then
      {
        inherit name;
        variant = "dark";
        dir = themeDirs.dark;
      }
    else if name == "jylhis-light" then
      {
        inherit name;
        variant = "light";
        dir = themeDirs.light;
      }
    else
      let
        scheme = loadScheme name;
      in
      {
        inherit name;
        inherit (scheme) variant;
        dir = mkSchemeThemeDir scheme;
      };
  resolvedThemes = map resolveTheme themeList;

  manifest = builtins.toJSON (
    map (t: {
      inherit (t) name variant;
      dir = "${t.dir}";
    }) resolvedThemes
  );

in
{
  config = lib.mkIf (desktopEnabled && themeEnabled) {
    # Declarative pointer to the active variant's assets. Managed by Home
    # Manager, so every activation resets it to the build-time default —
    # marchyo-theme-toggle repoints it (ln -sfn) at runtime.
    xdg.configFile."marchyo/current-theme".source = themeDirs.${buildVariant};

    # Manifest of every switchable theme (marchyo.theme.themes) for the CLI:
    # `marchyo theme list/set/next` read names + polarity + asset dirs here.
    # Listing the dirs also roots them in the profile closure, so switching
    # stays an instant symlink swap.
    xdg.dataFile."marchyo/themes/manifest.json".text = manifest;

    # Optional (`?`) include read through the pointer. Ghostty processes
    # config-file includes after the main file, so the included `theme`
    # overrides the build-time one from modules/home/ghostty.nix; both
    # variants' theme files are always installed by that module.
    programs.ghostty.settings.config-file = "?${config.xdg.configHome}/marchyo/current-theme/ghostty.conf";
  };
}
