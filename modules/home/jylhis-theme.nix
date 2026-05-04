# Adopt the upstream Jylhis Design System Home Manager module.
#
# Upstream: https://github.com/Jylhis/design/blob/main/nix/home-manager-module.nix
#
# The upstream module installs theme assets via xdg.configFile (no programs.*
# conflicts), driven by `jylhis.theme.variant ∈ { roast | paper }`. We translate
# from marchyo's variant naming (dark | light) and selectively disable targets
# that marchyo composes on top of (currently: waybar — see modules/home/waybar.nix).
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
  variant = if cfg.variant == "dark" then "roast" else "paper";
  makoConfig = if variant == "roast" then "config" else "config-paper";
in
{
  imports = [ inputs.jylhis-design.homeManagerModules.default ];

  config = lib.mkMerge [
    {
      jylhis.theme = {
        inherit (cfg) enable;
        inherit variant;
        waybar.enable = false;
        bat.enable = false;
        mako.enable = false;
        gtk.enable = false;
        # marchyo writes ghostty themes from mkPalette directly so the paper
        # ANSI 7/15 readability override (see jylhis-palette.nix) is honored.
        ghostty.enable = false;
        starship.enable = false;
      };
    }

    (lib.mkIf cfg.enable {
      xdg.configFile = {
        "mako/config".source = "${pkgs.jylhis-design-src}/platforms/mako/${makoConfig}";
        "starship.toml".source = "${pkgs.jylhis-design-src}/platforms/shell/starship.toml";
      };

      gtk = {
        gtk3.extraCss = builtins.readFile "${pkgs.jylhis-design-src}/platforms/gtk/gtk.css";
        gtk4.extraCss = builtins.readFile "${pkgs.jylhis-design-src}/platforms/gtk/gtk.css";
      };

      programs.starship.enable = lib.mkDefault true;
    })
  ];
}
