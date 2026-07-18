# Screensaver option declarations (platform-neutral; implementation lives in
# modules/home/screensaver.nix + the hypridle listener in
# modules/home/hypridle.nix).
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.screensaver = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        tte-based (terminaltexteffects) terminal screensaver launched on idle.
        Auto-enabled with `marchyo.desktop.enable` (the option only takes
        effect on a desktop); set false to opt out of the idle screensaver
        while keeping the rest of the desktop stack.
      '';
    };
  };
}
