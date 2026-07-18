# Notification do-not-disturb (omarchy parity): mako mode block, waybar
# indicator, toggle script, and the rebound comma keybinds.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;

  hm =
    (lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser {
          marchyo.desktop.enable = true;
          home-manager.users.testuser.imports = [ homeManagerModules ];
        })
      ];
    }).config.home-manager.users.testuser;

  binds = hm.wayland.windowManager.hyprland.settings.bindd or [ ];
  hasBind = s: lib.any (b: lib.hasInfix s b) binds;

  waybar = builtins.head hm.programs.waybar.settings;
in
{
  # DND on a desktop config: mako hides notifications in the do-not-disturb
  # mode, waybar carries the signal-refreshed custom/dnd segment, the toggle
  # script is installed, and SUPER CTRL, comma now toggles DND (dismiss-all
  # moved to SUPER CTRL SHIFT, comma).
  eval-dnd = pkgs.writeText "eval-dnd" (
    if
      hm.services.mako.settings."mode=do-not-disturb".invisible == 1
      && builtins.elem "custom/dnd" waybar.modules-right
      && waybar."custom/dnd".return-type == "json"
      && waybar."custom/dnd".signal == 9
      && waybar."custom/dnd".on-click == "marchyo-dnd-toggle"
      && lib.any (p: (p.name or "") == "marchyo-dnd-toggle") hm.home.packages
      && hasBind "SUPER CTRL, comma, Toggle do-not-disturb, exec, marchyo-dnd-toggle"
      && hasBind "SUPER CTRL SHIFT, comma, Dismiss all notifications, exec, makoctl dismiss --all"
      # The old dismiss-all bind must be gone from SUPER CTRL, comma.
      && !(hasBind "SUPER CTRL, comma, Dismiss all")
    then
      "pass"
    else
      throw "FAIL: DND mako mode, waybar custom/dnd segment, toggle script, or comma keybinds missing/malformed"
  );
}
