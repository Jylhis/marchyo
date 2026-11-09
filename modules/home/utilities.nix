# Omarchy-style "Trigger" utilities: reminders (transient systemd user timers),
# quick-info notifications (date/time, battery), and a media transcode + share
# pair. The logic lives in the marchyo CLI; this module installs the tool
# closure; the binds are in lib/keybinds.nix.
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  marchyoCfg = osConfig.marchyo;
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && marchyoCfg.desktop.enable;
  # `or true` mirrors the option defaults (desktop-cascade opt-outs).
  remindersEnabled = desktopEnabled && marchyoCfg.reminders.enable;
  utilitiesEnabled = desktopEnabled && marchyoCfg.utilities.enable;
in
{
  config = lib.mkMerge [
    (lib.mkIf remindersEnabled {
      home.packages = [
        pkgs.gum
        pkgs.libnotify
      ];
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

      # `marchyo font set` writes this optional include; ghostty processes it
      # after the main file, so its font-family wins for new windows. Merges
      # with theme-runtime.nix's current-theme include via HM list coercion.
      programs.ghostty.settings.config-file = "?${config.xdg.configHome}/marchyo/font-override.conf";
    })
  ];
}
