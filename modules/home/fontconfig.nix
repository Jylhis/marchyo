# Per-user fontconfig. HM's fontconfig makes fonts installed into the user
# profile visible (10-hm-fonts.conf). The role mapping (defaultFonts) lives in
# modules/nixos/fonts.nix so the greeter and other non-user processes see it
# too; it is repeated here only for standalone Home Manager, where no NixOS
# system provides it.
{
  osConfig ? { },
  lib,
  pkgs,
  ...
}:
let
  fonts = import "${pkgs.jylhis-design-src}/nix/fonts.nix";
in
{
  fonts.fontconfig = {
    enable = true;
    defaultFonts = lib.mkIf (!(osConfig ? fonts)) {
      serif = [ "DejaVu Serif" ];
      sansSerif = [ fonts.body ];
      monospace = [ fonts.mono ];
    };
  };
}
