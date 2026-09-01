# Adopt the upstream Jylhis Design System Home Manager module.
#
# Upstream: https://github.com/Jylhis/design/blob/main/nix/home-manager-module.nix
#
# The upstream module installs theme assets via xdg.configFile (no programs.*
# conflicts). Design v2.0.0 replaced the single `jylhis.theme.variant` with two
# orthogonal options — `name ∈ { survey | mono }` and `mode ∈ { light | dark }`.
# marchyo tracks the `survey` theme and maps its own variant naming (dark |
# light) straight onto `mode`, and selectively disables targets that marchyo
# composes on top of (currently: waybar — see modules/home/waybar.nix).
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
in
{
  imports = [ inputs.jylhis-design.homeManagerModules.default ];

  config = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.mkMerge [
      {
        jylhis.theme = {
          inherit (cfg) enable;
          name = "survey";
          mode = cfg.variant;
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

            # GTK3's CSS parser has no support for the GTK4/libadwaita custom
            # properties (`--accent-color: ...`) in the file's `.dark` block: it
            # emits "Expected semicolon" for each one, in waybar and in every other
            # GTK3 app. The GTK3 palette comes from @define-color and the file never
            # uses var(), so dropping these lines is lossless for GTK3.
            isCustomProp = line: builtins.match "[[:space:]]*--.*" line != null;
            gtk3Css = lib.concatLines (builtins.filter (l: !isCustomProp l) (lib.splitString "\n" designCss));
          in
          {
            gtk3.extraCss = gtk3Css;
            gtk4.extraCss = designCss;
          };
      })
    ]
  );
}
