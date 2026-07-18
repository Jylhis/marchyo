# Omarchy-parity "Trigger" utility toggles (see OMARCHY_PARITY.md Phase 3).
# Declarations only (platform-neutral; the darwin set imports this namespace
# too) - all configuration lives in the desktop-gated modules/home/utilities.nix.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo = {
    reminders.enable = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = ''
        Gum-driven desktop reminders: `marchyo-reminder-set`/`-show`/`-clear`
        (Super+Ctrl+R chords) schedule one-shot `systemd-run --user` timers
        that fire a critical notification, logged under
        `$XDG_STATE_HOME/marchyo/reminders`. Part of the desktop cascade -
        only active when `marchyo.desktop.enable` is set; set to `false` to
        opt out of the scripts and their keybindings.
      '';
    };

    utilities.enable = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = ''
        Quick-info and media utilities for the desktop: date/time and battery
        notifications (`marchyo-notify-datetime`/`-battery`,
        Super+Ctrl+Alt+T/B), the `marchyo-transcode` ffmpeg menu
        (Super+Ctrl+Period) and the `marchyo-share` clipboard helper (no
        keybinding - reached via the central menu). Part of the desktop
        cascade - only active when `marchyo.desktop.enable` is set; set to
        `false` to opt out of the scripts and their keybindings.
      '';
    };
  };
}
