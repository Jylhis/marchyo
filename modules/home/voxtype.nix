# Push-to-talk dictation via voxtype (Whisper). Wraps the upstream
# home-manager `services.voxtype` module: it writes ~/.config/voxtype/config.toml
# and runs the `voxtype` user service. Recording is driven from Hyprland
# (Super+H -> `voxtype record toggle`, wired in modules/home/hyprland.nix), so
# the daemon's built-in evdev hotkey stays disabled. Gated on
# marchyo.dictation.enable; Linux-only (Wayland dictation).
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  cfg = (osConfig.marchyo or { }).dictation or { };
  enabled = pkgs.stdenv.isLinux && (cfg.enable or false);
in
{
  config = lib.mkIf enabled {
    services.voxtype = {
      enable = true;

      # Pre-fetch the model at activation only when asked; otherwise voxtype
      # downloads it on first recording.
      loadModels = lib.optional (cfg.preloadModel or false) cfg.model;

      settings = {
        # Required for `record toggle` / `status` to share daemon state.
        state_file = "auto";
        engine = "whisper";
        # Driven by the Hyprland Super+H bind, not the daemon's evdev hotkey.
        hotkey.enabled = false;
        audio = {
          device = "default";
          sample_rate = 16000; # Whisper expects 16 kHz
          max_duration_secs = 60;
        };
        whisper = {
          inherit (cfg) model language;
          translate = false;
        };
        output = {
          mode = "type";
          fallback_to_clipboard = true;
        };
      };
    };
  };
}
