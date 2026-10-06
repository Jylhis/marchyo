# k9s with jylhis/base16 colors. The skin (lib/theme-generators.nix
# k9sSkinFromSlots) mirrors the retired Stylix k9s target's slot mapping
# exactly, with one substitution: its base11 dialog focus color does not exist
# in catalog schemes, so base00 stands in. Slots come from
# modules/generic/theme-slots.nix (Jylhis pair by variant, or
# marchyo.theme.scheme's catalog palette).
#
# On a Linux desktop the runtime theme layer (modules/home/theme-runtime.nix)
# owns the skin: skins/jylhis.yaml links to the current-theme's k9s-skin.yaml,
# and `marchyo theme` relinks it straight at the new theme dir so k9s's skins
# dir watcher restyles open sessions.
{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  theme = (osConfig.marchyo or { }).theme or { };
  themeEnabled = theme.enable or true;
  runtimeThemed =
    themeEnabled
    && pkgs.stdenv.hostPlatform.isLinux
    && ((osConfig.marchyo or { }).desktop.enable or false);
  s = import ../generic/theme-slots.nix {
    inherit pkgs lib;
    variant = theme.variant or "dark";
    scheme = theme.scheme or null;
  };
  gen = import ../../lib/theme-generators.nix { inherit lib; };
in
{
  config = lib.mkMerge [
    {
      programs.k9s = {
        enable = true;
        settings.ui.skin = lib.mkIf themeEnabled "jylhis";
        skins = lib.mkIf (themeEnabled && !runtimeThemed) { jylhis = gen.k9sSkinFromSlots s; };
      };
    }
    (lib.mkIf runtimeThemed {
      xdg.configFile."k9s/skins/jylhis.yaml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/marchyo/current-theme/k9s-skin.yaml";
    })
  ];
}
