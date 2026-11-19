# A chord with more than one owner fails the evaluation
# (lib/hotkey-claims.nix, modules/home/keybinds.nix).
{ lib, ... }:
let
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
in
{
  refs = {
    desktop.eval-hotkey-clashes-default = _: true;
    full.eval-hotkey-clashes-everything = _: true;
    desktop-tweaks-4.eval-hotkey-clashes-allowed =
      cfg: cfg.marchyo.keyboard.allowedHotkeyClashes == [ "SUPER + SHIFT + SPACE" ];
  };

  refConfig.desktop-tweaks-4 = {
    marchyo.keyboard.allowedHotkeyClashes = [ "SUPER + SHIFT + SPACE" ];
    home-manager.users.testuser.programs.ghostty.settings.keybind = [ "super+shift+space=new_tab" ];
  };

  failing = {
    hotkey-clash-ghostty = {
      on = "misconfigured-2";
      expect = [
        "Hotkey SHIFT + SUPER + space has several owners"
        "marchyo bind table (Toggle top bar)"
        "Ghostty (new_tab)"
      ];
    };
    hotkey-clash-host-bind = {
      on = "misconfigured-2";
      expect = [
        "Hotkey SUPER + space has several owners"
        "keyboard layout switching"
        "Hyprland binds of this configuration (Mine)"
      ];
    };
  };

  failingConfig.misconfigured-2.home-manager.users.testuser = {
    programs.ghostty.settings.keybind = [ "super+shift+space=new_tab" ];
    wayland.windowManager.hyprland.settings.bind = [
      (hlua.bindd "super + Space" "Mine" (hlua.exec "true"))
    ];
  };
}
