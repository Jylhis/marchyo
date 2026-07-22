# Runtime light/dark theme switching (omarchy parity, Phase 6 MVP).
#
# The declarative build-time variant (marchyo.theme.variant) stays the source
# of truth: this module additionally materializes BOTH variants'
# runtime-swappable assets into the store and ships `marchyo-theme-toggle`,
# which flips the desktop between them live — no rebuild. The switch is an
# ephemeral overlay: the next home-manager/NixOS activation resets every
# surface (and the ~/.config/marchyo/current-theme pointer) back to the
# declarative default.
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

  marchyo-theme-toggle = pkgs.writeShellApplication {
    name = "marchyo-theme-toggle";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      pkgs.mako
      pkgs.hyprland
      pkgs.libnotify
    ]
    ++ lib.optional wallpaperEnabled pkgs.awww;
    text = ''
      dark_dir='${themeDirs.dark}'
      light_dir='${themeDirs.light}'
      config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
      state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
      link="$config_home/marchyo/current-theme"
      state_file="$state_home/marchyo/theme"

      usage() {
        cat <<'EOF'
      Usage: marchyo-theme-toggle [toggle|dark|light|status]

      Switch the marchyo desktop between the dark (Jylhis Roast) and light
      (Jylhis Paper) variants at runtime, without a rebuild.

        toggle   flip to the other variant (default)
        dark     switch to the dark variant
        light    switch to the light variant
        status   print the active variant and exit

      Live-reloaded surfaces: wallpaper (awww), mako notifications, waybar,
      Hyprland border/background colors. Ghostty picks the new theme up on
      new windows (or via its reload_config keybind, default ctrl+shift+,).

      Rebuild-only surfaces (follow marchyo.theme.variant, not this toggle):
      GTK/Qt and all remaining Stylix targets, bat, fzf, starship, hyprlock,
      the console/TTY palette, and the plymouth boot splash.

      The switch is ephemeral: the next NixOS/home-manager activation resets
      everything to the declarative marchyo.theme.variant default.
      EOF
      }

      mode="''${1:-toggle}"
      case "$mode" in
        -h | --help)
          usage
          exit 0
          ;;
        toggle | dark | light | status) ;;
        *)
          usage >&2
          exit 1
          ;;
      esac

      # Active variant: the HM-managed current-theme symlink is the single
      # source of truth (it always exists after activation and is repointed
      # by this script); a missing link or unknown target falls back to the
      # build-time default.
      current='${buildVariant}'
      if [ -L "$link" ]; then
        resolved=$(readlink -f -- "$link" || true)
        case "$resolved" in
          "$dark_dir") current=dark ;;
          "$light_dir") current=light ;;
        esac
      fi

      if [ "$mode" = status ]; then
        echo "$current"
        exit 0
      fi

      if [ "$mode" = toggle ]; then
        if [ "$current" = dark ]; then target=light; else target=dark; fi
      else
        target="$mode"
      fi

      if [ "$target" = dark ]; then dir="$dark_dir"; else dir="$light_dir"; fi

      mkdir -p "$config_home/marchyo" "$state_home/marchyo"
      ln -sfn "$dir" "$link"
      # Write-only breadcrumb for external tooling (menus/CLI); the symlink
      # above is what this script reads back.
      printf '%s\n' "$target" >"$state_file"

      # Wallpaper — same command modules/home/hyprland.nix runs at startup.
      if [ -e "$dir/wallpaper.png" ] && command -v awww >/dev/null 2>&1; then
        awww img "$dir/wallpaper.png" --transition-type none || true
      fi

      # Mako re-reads its config on makoctl reload.
      if [ -e "$dir/mako.conf" ]; then
        mkdir -p "$config_home/mako"
        ln -sfn "$dir/mako.conf" "$config_home/mako/config"
        makoctl reload >/dev/null 2>&1 || true
      fi

      # Waybar: full unit restart (SIGUSR2 reload spawns duplicate instances,
      # see modules/home/waybar.nix). try-restart is a no-op when not running.
      if [ -e "$dir/waybar.css" ]; then
        mkdir -p "$config_home/waybar"
        ln -sfn "$dir/waybar.css" "$config_home/waybar/style.css"
        systemctl --user try-restart waybar.service 2>/dev/null || true
      fi

      # Hyprland colors via runtime keywords (`hyprctl reload` would re-read
      # the build-time config and revert them, so keywords only).
      if [ -e "$dir/hyprland.conf" ] && [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        while read -r keyword value; do
          [ -n "$keyword" ] || continue
          hyprctl keyword "$keyword" "$value" >/dev/null || true
        done <"$dir/hyprland.conf"
      fi

      notify-send -u low -a marchyo "Theme" "Switched to $target" || true
      echo "marchyo theme: $target (ghostty applies to new windows; see --help for rebuild-only surfaces)"
    '';
  };
in
{
  config = lib.mkIf (desktopEnabled && themeEnabled) {
    home.packages = [ marchyo-theme-toggle ];

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
