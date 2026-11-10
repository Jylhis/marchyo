# Per-user fontconfig. HM's fontconfig makes fonts installed into the user
# profile visible (10-hm-fonts.conf). The role mapping (defaultFonts) lives in
# modules/nixos/fonts.nix so the greeter and other non-user processes see it
# too.
{
  fonts.fontconfig.enable = true;
}
