{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
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
          size = 14;
        };
      };
    };
  };
}
