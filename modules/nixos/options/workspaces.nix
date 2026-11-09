# Hyprland workspace options. Declarations only.
{ lib, ... }:
{
  options.marchyo.workspaces.perMonitor = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Give every monitor its own workspaces 1-10. Each physical monitor
      (matched by make, model and serial) owns a block of ten Hyprland
      workspace ids: the laptop panel 1-10, the next monitor 11-20, and so
      on. The order of `marchyo.monitors` seeds the blocks. Super+1..0 act on
      the focused monitor's block and the bar labels each monitor's
      workspaces 1-10. The assignment is kept in
      `$XDG_STATE_HOME/marchyo/monitors/`; `marchyo monitor workspaces reset`
      clears it. Set to `false` for one global set of numbered workspaces.
    '';
  };
}
