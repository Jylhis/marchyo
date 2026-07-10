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

      # Give the daemon unit WAYLAND_DISPLAY plus wtype/wl-clipboard on PATH so
      # output.mode = "type" can type into Wayland windows (the module gates both
      # on this option). wayland-1 is Hyprland's primary socket.
      wayland.display = "wayland-1";

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
          # Sound cues on record start/stop (built-in), gated on the UI toggle.
          feedback = {
            enabled = cfg.audioFeedback or true;
            theme = "subtle";
          };
        };
        whisper = {
          inherit (cfg) model language;
          translate = false;
        };
        output = {
          mode = "type";
          fallback_to_clipboard = true;
          # Desktop notifications (mako) on start/stop/transcription, gated on
          # the UI toggle.
          notification = {
            on_recording_start = cfg.notify or true;
            on_recording_stop = cfg.notify or true;
            on_transcription = cfg.notify or true;
          };
        };
      };
    };
  };
}
