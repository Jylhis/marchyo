# Waybar click actions (omarchy parity): every top-bar action that opens a
# window must launch it with an org.omarchy.* --class matched by the
# floating-window tag rule in modules/home/hyprland.nix, so bar clicks open
# centered popups instead of tiling into the workspace — and the NixOS
# services those tools talk to must actually be enabled.
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

  cfgFor =
    extra:
    (lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    }).config;

  cfg = cfgFor { };
  hm = cfg.home-manager.users.testuser;
  waybar = builtins.head hm.programs.waybar.settings;
  windowrules = lib.concatStringsSep "\n" hm.wayland.windowManager.hyprland.settings.windowrule;

  # class every window-opening click must carry -> the on-click that opens it
  floatingClicks = {
    "org.omarchy.btop" = waybar.cpu.on-click;
    "org.omarchy.nmtui" = waybar.network.on-click;
    "org.omarchy.bluetui" = waybar.bluetooth.on-click;
    "org.omarchy.wiremix" = waybar.wireplumber.on-click;
    "org.omarchy.terminal" = waybar.battery.on-click;
  };

  badClicks = lib.filterAttrs (class: cmd: !lib.hasInfix "--class=${class}" cmd) floatingClicks;
  unruled = lib.filter (class: !lib.hasInfix class windowrules) (lib.attrNames floatingClicks);
in
{
  eval-waybar-click-actions = pkgs.writeText "eval-waybar-click-actions" (
    if badClicks != { } then
      throw "FAIL: waybar click actions missing a floating --class: ${toString (lib.attrNames badClicks)}"
    else if unruled != [ ] then
      throw "FAIL: no floating-window rule covers waybar popup class: ${toString unruled}"
    else if !(lib.hasInfix "marchyo menu power" waybar.battery.on-click) then
      throw "FAIL: battery click should open the power menu"
    else if !(lib.hasInfix "switchxkblayout" (waybar."hyprland/language".on-click or "")) then
      throw "FAIL: language click should cycle keyboard layouts"
    else
      "pass"
  );

  # The system services the click targets talk to are enabled on a desktop:
  # PipeWire/WirePlumber (wiremix, wpctl), bluez (bluetui), NetworkManager
  # (nmtui — Wi-Fi runs on the wpa_supplicant backend, NOT iwd, which crashes
  # while roaming; see docs/known-issues.md), and power-profiles-daemon/upower
  # (profile + battery segments).
  eval-waybar-backing-services = pkgs.writeText "eval-waybar-backing-services" (
    if
      cfg.services.pipewire.enable
      && cfg.services.pipewire.wireplumber.enable
      && cfg.hardware.bluetooth.enable
      && cfg.networking.networkmanager.enable
      && cfg.networking.networkmanager.wifi.backend != "iwd"
      && cfg.services.power-profiles-daemon.enable
      && cfg.services.upower.enable
    then
      "pass"
    else
      throw "FAIL: a NixOS service backing a waybar click target (pipewire, bluetooth, NetworkManager without the crash-prone iwd backend, power-profiles-daemon, upower) is not enabled"
  );

  # With the menus feature disabled marchyo-power-menu is not installed, so the
  # battery click falls back to the launcher instead of a dead command.
  eval-waybar-battery-menu-fallback =
    let
      waybar' =
        builtins.head
          (cfgFor { marchyo.menus.enable = false; }).home-manager.users.testuser.programs.waybar.settings;
    in
    pkgs.writeText "eval-waybar-battery-menu-fallback" (
      if waybar'.battery.on-click == "vicinae toggle" then
        "pass"
      else
        throw "FAIL: battery click should fall back to `vicinae toggle` when menus are disabled"
    );
}
