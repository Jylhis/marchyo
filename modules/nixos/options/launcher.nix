# Application launcher options. Declarations only.
{ lib, ... }:
{
  options.marchyo.launcher.enable = lib.mkEnableOption ''
    the launcher binds: Super+R (apps), Super+Ctrl+E (emoji picker) and
    Super+Ctrl+V (clipboard history) open the in-shell launcher of
    `marchyo.shell`. Auto-enabled (`lib.mkDefault`) when
    `marchyo.desktop.enable` is on; set to `false` to drop the binds'';
}
