# The trigger utilities and reminders, with their two opt-outs
# (desktop-off: marchyo.reminders.enable = false; desktop-tweaks-3:
# marchyo.utilities.enable = false).
{ helpers, lib, ... }:
let
  inherit (helpers) hyprHasBind hyprEntriesText;
  binds = hm: hm.wayland.windowManager.hyprland.settings.bind or [ ];
  hasBind = hm: hyprHasBind (binds hm);
  # Substring search over every rendered bind, for "no bind mentions X" checks.
  hasBindText = hm: s: lib.hasInfix s (hyprEntriesText (binds hm));
  hasPackage = hm: n: lib.any (p: lib.getName p == n) hm.home.packages;
in
{
  refs = {
    desktop = {
      # Desktop cascade: both toggles default on, so every script and bind lands.
      eval-utilities-enabled =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if
          hasBind hm "SUPER + CTRL + R" "-e marchyo reminder set"
          && hasBind hm "SUPER + CTRL + ALT + R" "Show reminders"
          && hasBind hm "SUPER + CTRL + SHIFT + R" "marchyo reminder clear"
          && hasBind hm "SUPER + CTRL + ALT + T" "marchyo info datetime"
          && hasBind hm "SUPER + CTRL + ALT + B" "marchyo info battery"
          && hasBind hm "SUPER + CTRL + period" "Transcode media"
          # Share stays deliberately unbound (CLI/central-menu entry); the
          # scripts were absorbed into the CLI, whose tools are installed.
          && hasPackage hm "gum"
          && !(hasBindText hm "marchyo share")
        then
          true
        else
          "desktop enabled but a trigger-utility bind or the CLI tool closure is missing, or share leaked a bind";
    };

    desktop-off = {
      # Reminders opt-out drops only the reminder binds; the rest stays.
      eval-utilities-reminders-disabled =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if
          !(hasBindText hm "marchyo reminder") && hasBind hm "SUPER + CTRL + ALT + T" "marchyo info datetime"
        then
          true
        else
          "reminders disabled but reminder binds/packages remain (or the utility binds vanished too)";
    };

    desktop-tweaks-3 = {
      # Utilities opt-out drops notify/transcode/share; reminders stay.
      eval-utilities-disabled =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if
          !(hasBindText hm "marchyo info datetime")
          && !(hasBindText hm "marchyo transcode")
          && hasBind hm "SUPER + CTRL + R" "Set reminder"
        then
          true
        else
          "utilities disabled but notify/transcode/share remain (or the reminder binds vanished too)";
    };
  };

  refConfig = {
    desktop-off.marchyo.reminders.enable = false;
    desktop-tweaks-3.marchyo.utilities.enable = false;
  };
}
