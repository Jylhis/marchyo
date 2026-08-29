{ lib, ... }:
{
  options.marchyo.shell.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Experimental unified Quickshell desktop shell. When enabled, a single
      long-running Quickshell process renders a Jylhis-themed top bar (Phase 1:
      workspaces, clock, tray, audio, battery, network, bluetooth, CPU, power
      profile), launched as a graphical-session user service. Opt-in and off by
      default: it runs alongside — and does not yet replace — the discrete
      waybar/mako/swayosd stack, so it is not cascaded from
      `marchyo.desktop.enable`. See plans/shell.md for the roadmap.
    '';
  };
}
