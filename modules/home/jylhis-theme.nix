# Jylhis design system: GTK stylesheet, pointer cursor and interface fonts,
# read from the vendored design files in lib/design (pkgs.jylhis-design-src).
# Every other surface (ghostty, bat, starship, fzf, …) is composed by its own
# module from the same files.
{
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

  fonts = import "${pkgs.jylhis-design-src}/nix/fonts.nix";

  # Per-polarity GTK stylesheet: the committed snapshot carries the active
  # polarity's @define-colors at top level, so no filtering or hex swap is needed.
  gtkCss = builtins.readFile "${pkgs.jylhis-design-src}/platforms/gtk/jylhis-${mode}.css";
in
{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && cfg.enable) {
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
          name = fonts.body;
          size = fs.round 12;
        };
        dconf.settings."org/gnome/desktop/interface" = {
          document-font-name = lib.mkDefault "${fonts.body} ${toString (fs.round 12 - 1)}";
          monospace-font-name = lib.mkDefault "${fonts.mono} ${toString (fs.round 12)}";
        };

        # Read as text (not readFile of a derivation) to stay IFD-free, and so
        # theme-runtime.nix can hex-swap a copy per theme dir. Font size is NOT
        # set here: the dconf interface fonts above cover GTK apps via
        # gsettings even under Hyprland.
        gtk = {
          gtk3.extraCss = gtkCss;
          gtk4.extraCss = gtkCss;
        };
      };
}
