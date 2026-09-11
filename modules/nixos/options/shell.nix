{ lib, ... }:
{
  options.marchyo.shell.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Experimental unified Quickshell desktop shell. When enabled, a single
      long-running Quickshell process renders the Jylhis-themed top bar
      (workspaces, clock, tray, audio, battery, network, bluetooth, CPU,
      power profile), the OSD, the audio/network/power/monitor panels, and
      the notification toasts — replacing waybar, SwayOSD, and mako (each
      mutually exclusive; see tests/eval/marchyo-shell.nix). Opt-in and off
      by default; it is not cascaded from `marchyo.desktop.enable`.
      Vicinae (launcher) and hyprlock (lock) stay. See plans/shell.md for
      the roadmap.
    '';
  };
}
