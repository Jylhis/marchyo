# Mako notification daemon — marchyo-owned config.
#
# Uses home-manager's services.mako, which installs the mako package AND
# starts the mako.service user unit (bound to graphical-session.target) so
# notifications actually appear as small corner toasts. Replaces the upstream
# Jylhis design mako config (disabled in modules/home/jylhis-theme.nix) so we
# can enforce the TUI aesthetic (sharp corners, single-line border) while
# keeping every color sourced from the Jylhis design tokens via
# modules/generic/jylhis-palette.nix.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";

  palette = import ../generic/jylhis-palette.nix {
    inherit pkgs lib;
    variant = themeVariant;
  };
in
{
  config = lib.mkIf desktopEnabled {
    services.mako = {
      enable = true;
      settings = {
        font = "JetBrainsMono Nerd Font 10";
        anchor = "top-right";
        margin = "10";
        border-radius = 0;
        border-size = 2;
        padding = 8;
        width = 380;
        default-timeout = 5000;

        background-color = palette.hex.bg;
        text-color = palette.hex.text;
        border-color = palette.hex.accent;
        # Accent progress, as in the upstream mako config — surface-on-bg was
        # too low-contrast to read as a progress bar.
        progress-color = "over ${palette.hex.accent}";

        "urgency=low".border-color = palette.hex."text-faint";

        "urgency=critical" = {
          border-color = palette.hex."status-err";
          default-timeout = 0;
        };
      };
    };
  };
}
