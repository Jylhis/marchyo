{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  dpmsOn = hlua.hyprDispatch ''dpms({ action = "on" })'';
  dpmsOff = hlua.hyprDispatch ''dpms({ action = "off" })'';
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && osConfig.marchyo.desktop.enable;
  screensaverEnabled = osConfig.marchyo.screensaver.enable;

  # With the unified shell on, the in-shell WlSessionLock (`marchyo shell lock`)
  # replaces hyprlock/loginctl as the lock actuation. hypridle stays the single
  # idle authority so `marchyo toggle idle` (which stops this service) keeps
  # disabling idle lock.
  shellEnabled = osConfig.marchyo.shell.enable;
  # The store path when the CLI is not installed system-wide, so idle locking
  # never depends on marchyo.cli.enable.
  cliEnabled = osConfig.marchyo.cli.enable;
  marchyoCli = if cliEnabled then "marchyo" else lib.getExe pkgs.marchyo-cli;
  shellLockCmd = "${marchyoCli} shell lock";
in
{
  config = lib.mkIf desktopEnabled {
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = if shellEnabled then shellLockCmd else "pidof hyprlock || hyprlock";
          before_sleep_cmd = if shellEnabled then shellLockCmd else "loginctl lock-session";
          after_sleep_cmd = dpmsOn;
          inhibit_sleep = 3;
        };

        listener =
          # Terminal screensaver (modules/home/screensaver.nix), slotted just before
          # the 150s dim so the animation starts on a fully lit screen. on-resume
          # dismisses it (the script also exits on keypresses, but mouse motion only
          # reaches hypridle).
          lib.optionals screensaverEnabled [
            {
              timeout = 120;
              on-timeout = "marchyo-screensaver-launch";
              on-resume = "pkill -f class=org.omarchy.screensaver || true";
            }
          ]
          ++ [
            {
              timeout = 150;
              on-timeout = "brightnessctl -s set 10";
              on-resume = "brightnessctl -r";
            }
            {
              timeout = 300;
              on-timeout = if shellEnabled then shellLockCmd else "loginctl lock-session";
            }
            {
              timeout = 330;
              on-timeout = dpmsOff;
              on-resume = dpmsOn;
            }
          ];
      };
    };
  };
}
