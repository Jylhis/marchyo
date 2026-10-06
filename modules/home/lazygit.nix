# lazygit with jylhis/base16 colors. The gui.theme mapping
# (lib/theme-generators.nix lazygitThemeFromSlots) mirrors the slot mapping
# the retired Stylix lazygit target used; slots come from
# modules/generic/theme-slots.nix (Jylhis pair by variant, or
# marchyo.theme.scheme's catalog palette).
#
# On a Linux desktop the runtime theme layer (modules/home/theme-runtime.nix)
# ships lazygit.yml in every theme dir. LG_CONFIG_FILE lists the main
# config.yml and then current-theme/lazygit.yml; lazygit unmarshals the files
# in order onto one config, so the runtime gui.theme replaces the build-time
# one at each lazygit start. lazygit errors on a missing LG_CONFIG_FILE entry,
# so the variable is set only while the main config.yml is generated.
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
  cfg = config.programs.lazygit;
in
{
  config = lib.mkMerge [
    {
      programs.lazygit = {
        enable = true;
        settings.gui.theme = lib.mkIf themeEnabled (gen.lazygitThemeFromSlots s);
      };
    }
    (lib.mkIf (runtimeThemed && cfg.enable && cfg.settings != { }) {
      home.sessionVariables.LG_CONFIG_FILE = lib.concatStringsSep "," [
        "${config.xdg.configHome}/lazygit/config.yml"
        "${config.xdg.configHome}/marchyo/current-theme/lazygit.yml"
      ];
    })
  ];
}
