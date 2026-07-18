{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  screensaverEnabled = (osConfig.marchyo or { }).screensaver.enable or true;
  hibernation = (osConfig.marchyo or { }).power.hibernation or { };
  hibernationEnabled = hibernation.enable or false;
  idleSleepCmd =
    if hibernation.suspendThenHibernate or true then
      "systemctl suspend-then-hibernate"
    else
      "systemctl suspend";
in
{
  config = lib.mkIf desktopEnabled {
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
          inhibit_sleep = 3;
        };

        listener =
          # Terminal screensaver (modules/home/screensaver.nix). Omarchy fires
          # it at ~150s, but marchyo dims at exactly 150s — slot it just ahead
          # so the animation starts on a fully lit screen. on-resume dismisses
          # it on any input (the script also exits on keypresses it receives
          # directly, but mouse motion only reaches hypridle).
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
              on-timeout = "loginctl lock-session";
            }
            {
              timeout = 330;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
          ]
          # Sleep on long idle only when the host opted into hibernation —
          # suspend-then-hibernate (or plain suspend when suspendThenHibernate
          # is off) after 30 minutes.
          ++ lib.optionals hibernationEnabled [
            {
              timeout = 1800;
              on-timeout = idleSleepCmd;
            }
          ];
      };
    };
  };
}
