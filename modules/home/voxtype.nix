# Push-to-talk dictation via voxtype (Whisper). Wraps the upstream
# home-manager `services.voxtype` module: it writes ~/.config/voxtype/config.toml
# and runs the `voxtype` user service. Recording is driven two ways (omarchy
# parity): the daemon's evdev push-to-talk hotkey (hold F9 by default; see
# marchyo.dictation.pushToTalk) and a Hyprland `voxtype record toggle` bind
# (Super+Ctrl+X by default; see marchyo.dictation.toggleKey, wired in
# modules/home/hyprland.nix). The evdev hotkey needs the user in the `input`
# group, added by modules/nixos/dictation.nix. Gated on marchyo.dictation.enable;
# Linux-only (Wayland dictation).
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  cfg = (osConfig.marchyo or { }).dictation or { };
  enabled = pkgs.stdenv.hostPlatform.isLinux && (cfg.enable or false);
in
{
  config = lib.mkIf enabled {
    services.voxtype = {
      enable = true;

      # GPU-accelerated (Vulkan) Whisper backend by default: the stock
      # pkgs.voxtype is a source build with no GPU engine compiled in, so it
      # runs large-v3-turbo on CPU (slow). pkgs.voxtype-vulkan enables the
      # gpu-vulkan Cargo feature; Vulkan covers NVIDIA/AMD/Intel and falls back
      # to CPU when no device is present. Escape hatch: marchyo.dictation.gpu.
      package = if (cfg.gpu or true) then pkgs.voxtype-vulkan else pkgs.voxtype;

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
        # The daemon's built-in OSD defaults to on and spawns `voxtype-osd`,
        # which is not on the voxtype-vulkan unit PATH (it ships in plain
        # pkgs.voxtype). Desktop notifications already cover start/stop feedback,
        # so disable the OSD to stop the "Failed to spawn voxtype-osd" warning.
        osd.enabled = false;
        # Daemon evdev push-to-talk hotkey (hold F9 by default). Disabling it via
        # marchyo.dictation.pushToTalk.enable = false leaves only the Hyprland
        # toggle bind (`voxtype record toggle`), which needs no /dev/input access.
        hotkey =
          if (cfg.pushToTalk.enable or true) then
            {
              enabled = true;
              inherit (cfg.pushToTalk) key mode;
            }
          else
            {
              enabled = false;
            };
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
          # Free VRAM/host memory between dictations rather than pinning the
          # model resident (marchyo.dictation.onDemandModel); gpu_isolation lets
          # a discrete GPU sleep between recordings (marchyo.dictation.gpuIsolation).
          on_demand_loading = cfg.onDemandModel or false;
          gpu_isolation = cfg.gpuIsolation or false;
        };
        # Silence gate (marchyo.dictation.silenceGate): voice activity detection
        # drops recordings with no speech before Whisper sees them, so silence
        # never transcribes into hallucinated text.
        vad = {
          enabled = cfg.silenceGate.enable;
          inherit (cfg.silenceGate) backend threshold;
          min_speech_duration_ms = cfg.silenceGate.minSpeechMs;
        };
        output = {
          mode = "type";
          fallback_to_clipboard = true;
          # Desktop notifications on start/stop/transcription, gated on
          # the UI toggle.
          notification = {
            on_recording_start = cfg.notify or true;
            on_recording_stop = cfg.notify or true;
            on_transcription = cfg.notify or true;
          };
        };
      }
      // lib.optionalAttrs (cfg.spokenPunctuation or false || (cfg.replacements or { }) != { }) {
        # Deterministic transcript post-processing (marchyo.dictation.replacements
        # / spokenPunctuation). Only emitted when configured, so the default
        # config stays untouched.
        text = {
          spoken_punctuation = cfg.spokenPunctuation or false;
          replacements = cfg.replacements or { };
        };
      };
    };
  };
}
