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
  fs = import ../../lib/font-scale.nix {
    inherit lib;
    scale = cfg.fontScale or 1.25;
  };

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
        # marchyo owns the GTK module outright (no Stylix): the dconf keys and
        # icon theme land in modules/home/gtk.nix, the CSS below.
        gtk.enable = lib.mkDefault true;

        home.pointerCursor = {
          enable = lib.mkDefault true;
          name = lib.mkDefault "Adwaita";
          package = lib.mkDefault pkgs.adwaita-icon-theme;
          size = lib.mkDefault 24;
        };

        # GNOME interface fonts (dconf): what GTK/Qt/Electron apps resolve as
        # the default UI font. The formula mirrors the retired Stylix `gnome`
        # target (document = applications - 1). `gtk.font` carries font-name
        # (plus the GTK settings.ini); the two dconf keys HM has no options
        # for are written directly.
        gtk.font = lib.mkDefault {
          name = "Hanken Grotesk";
          size = fs.round 12;
        };
        dconf.settings."org/gnome/desktop/interface" = {
          document-font-name = lib.mkDefault "Zilla Slab ${toString (fs.round 12 - 1)}";
          monospace-font-name = lib.mkDefault "BlexMono Nerd Font ${toString (fs.round 12)}";
        };

        # Read as text (not readFile of a derivation) to stay IFD-free, and so
        # theme-runtime.nix can hex-swap a copy per theme dir. Font size is NOT
        # set here: the dconf interface fonts above cover GTK apps via
        # gsettings even under Hyprland.
        gtk = {
          gtk3.extraCss = gtkCss;
          gtk4.extraCss = gtkCss;
        };
      })
    ]
  );
}
