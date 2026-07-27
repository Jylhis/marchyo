{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  fontScale = (osConfig.marchyo or { }).theme.fontScale or 1.0;
  fs = import ../../lib/font-scale.nix {
    inherit lib;
    scale = fontScale;
  };
in
{
  config = lib.mkIf desktopEnabled {
    programs.vicinae = {
      enable = true;
      systemd.enable = true; # run the daemon as a user service (Restart=always, WantedBy=graphical-session.target)
      settings = {
        # TUI aesthetic — opaque, sharp corners
        window = {
          opacity = 1.0;
          rounding = 0;
        };

        font = {
          size = fs.round 14;
        };
      };
    };
  };
}
