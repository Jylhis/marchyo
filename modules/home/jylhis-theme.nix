# Adopt the upstream Jylhis Design System Home Manager module.
#
# Upstream: https://github.com/Jylhis/design/blob/main/nix/home-manager-module.nix
#
# The upstream module installs theme assets via xdg.configFile (no programs.*
# conflicts), driven by two orthogonal options `jylhis.theme.name ∈ { survey |
# mono }` × `jylhis.theme.mode ∈ { light | dark }`. We translate from marchyo's
# variant naming (dark | light) onto the Survey theme's mode and selectively
# disable targets that marchyo composes on top of (currently: waybar — see
# modules/home/waybar.nix).
{
  inputs,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  cfg =
    (osConfig.marchyo or { }).theme or {
      enable = true;
      variant = "dark";
    };
  mode = if cfg.variant == "dark" then "dark" else "light";

  # The upstream gtk.css is generated with the LIGHT palette baked into its
  # top-level `@define-color`s and a `.dark { --custom-prop }` block that only
  # works on GTK4/libadwaita (GTK3 can't parse custom properties at all) and
  # never overrides the top-level @define-colors. User CSS loads after the
  # theme, so those light @define-colors beat Adwaita-dark — every GTK app
  # (Nautilus, ghostty's tab bar, …) rendered light under the dark theme.
  #
  # Fix: translate the light-palette hexes to the active variant's with
  # builtins.replaceStrings over the same semantic-token palettes
  # modules/generic/jylhis-palette.nix exports (identical machinery to
  # modules/home/theme-runtime.nix). The `.dark` block's dark hexes don't
  # collide with any light token hex (audited), so they're left as-is. Build
  # variant only — runtime switching of gtk.css is future work.
  mkGtkPalette = variant: import ../generic/jylhis-palette.nix { inherit pkgs lib variant; };
  paletteHexes = v: builtins.attrValues (mkGtkPalette v).hex;
  swapToVariant =
    if cfg.variant == "dark" then
      builtins.replaceStrings (paletteHexes "light") (paletteHexes "dark")
    else
      lib.id;
in
{
  imports = [ inputs.jylhis-design.homeManagerModules.default ];

  config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkMerge [
      {
        jylhis.theme = {
          inherit (cfg) enable;
          name = "survey";
          inherit mode;
          waybar.enable = false;
          bat.enable = false;
          mako.enable = false;
          gtk.enable = false;
          # ghostty themes are installed cross-platform (darwin included) by
          # modules/home/ghostty.nix from the same upstream theme files.
          ghostty.enable = false;
          starship.enable = false;
          # fzf colors are set cross-platform via programs.fzf.colors in
          # modules/home/fzf.nix (the upstream target mkForce-overwrites
          # FZF_DEFAULT_OPTS, which would drop marchyo's layout options).
          fzf.enable = false;
        };
      }

      (lib.mkIf cfg.enable {
        # Stylix populates home.pointerCursor.{name,package,size} (see
        # modules/generic/stylix.nix) but not its enable flag. Recent
        # home-manager deprecates relying on those sub-options to trigger
        # cursor config generation, so opt in explicitly (gated on the same
        # theme.enable that gates stylix). mkDefault lets a consumer override.
        home.pointerCursor.enable = lib.mkDefault true;

        # mako is themed by modules/home/mako.nix (TUI override); starship is
        # configured cross-platform in modules/home/starship.nix.
        # GTK app font size is NOT set here: marchyo disables only Stylix's
        # `gtk` target (which would write gtk settings.ini / CSS), but Stylix's
        # `gnome` target stays enabled and writes the scaled interface font to
        # dconf `org/gnome/desktop/interface font-name` (e.g. "Hanken Grotesk 15"
        # at fontScale 1.25), which GTK apps read via the gsettings backend even
        # under Hyprland. Setting gtk.font here would collide with that dconf key.
        gtk =
          let
            designCss = builtins.readFile "${pkgs.jylhis-design-src}/platforms/gtk/gtk.css";
            variantCss = swapToVariant designCss;

            # GTK3's CSS parser has no support for the GTK4/libadwaita custom
            # properties (`--accent-color: ...`) in the file's `.dark` block: it
            # emits "Expected semicolon" for each one, in waybar and in every other
            # GTK3 app. The GTK3 palette comes from @define-color and the file never
            # uses var(), so dropping these lines is lossless for GTK3.
            isCustomProp = line: builtins.match "[[:space:]]*--.*" line != null;
            gtk3Css = lib.concatLines (builtins.filter (l: !isCustomProp l) (lib.splitString "\n" variantCss));
          in
          {
            gtk3.extraCss = gtk3Css;
            gtk4.extraCss = variantCss;
          };
      })
    ]
  );
}
