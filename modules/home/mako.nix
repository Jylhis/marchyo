# Mako notification daemon, marchyo-owned config. Replaces the upstream Jylhis
# design mako config (disabled in modules/home/jylhis-theme.nix) to enforce the
# TUI aesthetic while sourcing colors from modules/generic/jylhis-palette.nix.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  # The unified shell owns org.freedesktop.Notifications, so mako stands down
  # when the shell is on (same mutual exclusion as waybar.nix / swayosd.nix);
  # the two daemons never both bind the notification bus.
  shellEnabled = ((osConfig.marchyo or { }).shell or { }).enable or false;
  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";

  palette = import ../generic/jylhis-palette.nix {
    inherit pkgs lib;
    variant = themeVariant;
  };

  fontScale = (osConfig.marchyo or { }).theme.fontScale or 1.0;
  fs = import ../../lib/font-scale.nix {
    inherit lib;
    scale = fontScale;
  };
in
{
  config = lib.mkIf (desktopEnabled && !shellEnabled) {
    services.mako = {
      enable = true;
      settings = {
        font = "BlexMono Nerd Font ${toString (fs.round 10)}";
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
        # Accent progress: surface-on-bg was too low-contrast to read as a bar.
        progress-color = "over ${palette.hex.accent}";

        "urgency=low".border-color = palette.hex."text-faint";

        "urgency=critical" = {
          border-color = palette.hex."status-err";
          default-timeout = 0;
        };

        # While active, notifications are hidden but still queue and reappear
        # when the mode is left. Toggled from window-toggles.nix.
        "mode=do-not-disturb".invisible = 1;
      };
    };
  };
}
