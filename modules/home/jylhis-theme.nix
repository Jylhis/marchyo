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
  osConfig ? { },
  ...
}:
let
  cfg =
    (osConfig.marchyo or { }).theme or {
      enable = true;
      variant = "dark";
    };
in
{
  imports = [ inputs.jylhis-design.homeManagerModules.default ];

  jylhis.theme = {
    inherit (cfg) enable;
    variant = if cfg.variant == "dark" then "roast" else "paper";
    waybar.enable = false;
    bat.enable = false;
    # marchyo writes ghostty themes from mkPalette directly so the paper
    # ANSI 7/15 readability override (see jylhis-palette.nix) is honored.
    ghostty.enable = false;
    starship.enable = true;
  };

  programs.starship.enable = lib.mkDefault true;
}
