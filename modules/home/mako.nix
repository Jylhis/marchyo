# Mako notification styling — marchyo-owned config.
#
# Replaces the upstream Jylhis design mako config (disabled in
# modules/home/jylhis-theme.nix) so we can enforce the TUI aesthetic
# (sharp corners, single-line border) while keeping every color sourced
# from the Jylhis design tokens via modules/generic/jylhis-palette.nix.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  themeEnabled = (osConfig.marchyo or { }).theme.enable or true;

  palette = import ../generic/jylhis-palette.nix {
    inherit pkgs lib;
    variant = themeVariant;
  };
in
{
  config = lib.mkIf (pkgs.stdenv.isLinux && themeEnabled) {
    xdg.configFile."mako/config".text = ''
      font=JetBrainsMono Nerd Font 10
      border-radius=0
      border-size=2
      padding=8
      width=380
      default-timeout=5000

      background-color=${palette.hex.bg}
      text-color=${palette.hex.text}
      border-color=${palette.hex.accent}
      progress-color=over ${palette.hex.surface}

      [urgency=low]
      border-color=${palette.hex."text-faint"}

      [urgency=critical]
      border-color=${palette.hex."status-err"}
      default-timeout=0
    '';
  };
}
