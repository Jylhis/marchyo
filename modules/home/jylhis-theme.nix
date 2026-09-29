# Adopt the upstream Jylhis Design System Home Manager module.
# Upstream: https://github.com/Jylhis/design/blob/main/nix/home-manager-module.nix
#
# Driven by jylhis.theme.mode (light|dark); we translate from marchyo's variant.
# Every target is disabled because marchyo composes each surface itself from
# IFD-free sources: the upstream gtk/mako/waybar targets readFile the built
# package at eval time, which is import-from-derivation, banned in this flake.
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

  # Per-polarity GTK stylesheet: the committed snapshot carries the active
  # polarity's @define-colors at top level, so no filtering or hex swap is needed.
  gtkCss = builtins.readFile "${inputs.jylhis-design}/platforms/gtk/jylhis-${mode}.css";
in
{
  imports = [ inputs.jylhis-design.homeManagerModules.default ];

  config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkMerge [
      {
        jylhis.theme = {
          inherit (cfg) enable;
          name = "jylhis";
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
        # Stylix populates home.pointerCursor.{name,package,size} but not its
        # enable flag, and home-manager no longer infers it from those, so opt
        # in explicitly. mkDefault lets a consumer override.
        home.pointerCursor.enable = lib.mkDefault true;

        # Read as text (not readFile of a derivation) to stay IFD-free, and so
        # theme-runtime.nix can hex-swap a copy per theme dir. Font size is NOT
        # set here: Stylix's gnome target writes the scaled interface font to
        # dconf, which GTK apps read via gsettings even under Hyprland.
        gtk = {
          gtk3.extraCss = gtkCss;
          gtk4.extraCss = gtkCss;
        };
      })
    ]
  );
}
