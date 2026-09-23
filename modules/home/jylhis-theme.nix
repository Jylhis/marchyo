# Adopt the upstream Jylhis Design System Home Manager module.
#
# Upstream: https://github.com/Jylhis/design/blob/main/nix/home-manager-module.nix
#
# The upstream module installs theme assets via xdg.configFile (no programs.*
# conflicts), driven by `jylhis.theme.mode ∈ { light | dark }` (design system
# 3.0.0 is single-theme; `jylhis.theme.name` is pinned to "jylhis" upstream
# and kept only for config compatibility). We translate from marchyo's
# variant naming (dark | light) and disable every target: marchyo composes
# each surface itself, from sources that keep marchyo IFD-free —
#  - generated-only assets (ghostty themes, per-polarity gtk css) come from
#    the built pkgs.jylhis-themes package as path references
#    (modules/home/ghostty.nix, the gtk block below);
#  - the upstream gtk/mako/waybar targets readFile the built package at eval
#    time, which is import-from-derivation — banned in this flake
#    (nixbuild.net);
#  - text surfaces marchyo runtime-hex-swaps (mako config, waybar css) read
#    the committed platforms/_reference files from the source tree instead.
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

  # Per-polarity GTK stylesheet, text from the committed upstream snapshot
  # (design 3.0.0; the file carries the active polarity's @define-colors at
  # top level, so no .dark custom-prop filtering or hex swap is needed for
  # either GTK version).
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
        # Stylix populates home.pointerCursor.{name,package,size} (see
        # modules/generic/stylix.nix) but not its enable flag. Recent
        # home-manager deprecates relying on those sub-options to trigger
        # cursor config generation, so opt in explicitly (gated on the same
        # theme.enable that gates stylix). mkDefault lets a consumer override.
        home.pointerCursor.enable = lib.mkDefault true;

        # GTK user CSS: the per-polarity stylesheet design 3.0.0 generates
        # and commits (platforms/gtk/jylhis-<mode>.css — one file carrying
        # the active polarity's @define-colors, valid for GTK3 and GTK4
        # alike; replaces the pre-3.0 hex-swap stopgap over the light-baked
        # gtk.css). Read as text from the committed source-tree snapshot so
        # evaluation stays import-from-derivation-free, and so the runtime
        # layer (modules/home/theme-runtime.nix) can hex-swap a copy per
        # theme dir. GTK app font size is NOT set here: Stylix's `gnome`
        # target writes the scaled interface font to dconf
        # `org/gnome/desktop/interface font-name`, which GTK apps read via
        # the gsettings backend even under Hyprland.
        gtk = {
          gtk3.extraCss = gtkCss;
          gtk4.extraCss = gtkCss;
        };
      })
    ]
  );
}
