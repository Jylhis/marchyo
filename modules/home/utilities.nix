# Omarchy-style "Trigger" utilities (OMARCHY_PARITY.md Phase 3): reminders
# backed by transient systemd user timers, quick-info notifications
# (date/time, battery), and a media transcode + share pair. The logic lives
# in the marchyo CLI (`marchyo reminder|info|transcode|share`, absorbed from
# the seven former scripts here); this module installs the tool closure and
# contributes the binds, which merge into
# wayland.windowManager.hyprland.settings the same way webapps.nix
# contributes its launch binds (list-valued Hyprland settings concatenate
# across Home Manager modules, so hyprland.nix stays untouched).
#
# It also wires the ghostty font-override include for `marchyo font set`:
# the optional (`?`) include is processed after the main config, so a
# runtime-written `font-family` wins for new windows and vanishes with
# `marchyo font set --revert`.
{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  marchyoCfg = osConfig.marchyo or { };
  desktopEnabled = pkgs.stdenv.isLinux && (marchyoCfg.desktop.enable or false);
  # `or true` mirrors the option defaults (desktop-cascade opt-outs).
  remindersEnabled = desktopEnabled && ((marchyoCfg.reminders or { }).enable or true);
  utilitiesEnabled = desktopEnabled && ((marchyoCfg.utilities or { }).enable or true);

  # Interactive commands run in the floating terminal (the
  # keybindings-cheatsheet pattern: org.omarchy.terminal picks up the
  # centered floating-window rule); the notify commands run directly.
  reminderBinds = [
    (hlua.bindd "SUPER + CTRL + R" "Set reminder" (hlua.execInTerminal "marchyo reminder set"))
    (hlua.bindd "SUPER + CTRL + ALT + R" "Show reminders" (hlua.execInTerminal "marchyo reminder show"))
    (hlua.bindd "SUPER + CTRL + SHIFT + R" "Clear reminders" (hlua.exec "marchyo reminder clear"))
  ];
  utilityBinds = [
    (hlua.bindd "SUPER + CTRL + ALT + T" "Show date and time" (hlua.exec "marchyo info datetime"))
    (hlua.bindd "SUPER + CTRL + ALT + B" "Show battery status" (hlua.exec "marchyo info battery"))
    (hlua.bindd "SUPER + CTRL + period" "Transcode media" (hlua.execInTerminal "marchyo transcode"))
  ];
in
{
  config = lib.mkMerge [
    (lib.mkIf remindersEnabled {
      home.packages = [
        pkgs.gum
        pkgs.libnotify
      ];
      wayland.windowManager.hyprland.settings.bind = reminderBinds;
    })
    (lib.mkIf utilitiesEnabled {
      home.packages = [
        pkgs.gum
        pkgs.ffmpeg
        pkgs.libnotify
        pkgs.wl-clipboard
        pkgs.fontconfig # fc-list / fc-match for `marchyo font`
      ]
      ++ lib.optional (pkgs ? terminaltexteffects) pkgs.terminaltexteffects;
      wayland.windowManager.hyprland.settings.bind = utilityBinds;

      # `marchyo font set` writes this optional include (ghostty processes
      # config-file includes after the main file, so its font-family wins
      # for new windows). Merges with theme-runtime.nix's current-theme
      # include via HM's duplicate-key list coercion.
      programs.ghostty.settings.config-file = "?${config.xdg.configHome}/marchyo/font-override.conf";
    })
  ];
}
