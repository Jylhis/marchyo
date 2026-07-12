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
in
{
  imports = [ inputs.jylhis-design.homeManagerModules.default ];

  config = lib.mkIf pkgs.stdenv.isLinux (
    lib.mkMerge [
      {
        jylhis.theme = {
          inherit (cfg) enable;
          inherit variant;
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
        # mako is themed by modules/home/mako.nix (TUI override); starship is
        # configured cross-platform in modules/home/starship.nix.
        gtk = {
          gtk3.extraCss = builtins.readFile "${pkgs.jylhis-design-src}/platforms/gtk/gtk.css";
          gtk4.extraCss = builtins.readFile "${pkgs.jylhis-design-src}/platforms/gtk/gtk.css";
        };
      })
    ]
  );
}
