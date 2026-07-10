{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.dictation = {
    enable = lib.mkEnableOption ''
      push-to-talk voice dictation (voxtype + Whisper) for the Wayland desktop.
      Runs the voxtype daemon as a user service and binds Super+H under Hyprland
      to toggle recording; transcribed text is typed at the cursor. Requires a
      microphone. The first recording downloads the Whisper model (~1.5 GB)
      unless preloadModel pulls it at activation time'';

    model = mkOption {
      type = types.str;
      default = "large-v3-turbo";
      description = ''
        Whisper model voxtype loads for transcription. large-v3-turbo is
        multilingual and fast; smaller models (e.g. base, small) trade accuracy
        for a smaller download and lower latency.
      '';
    };

    language = mkOption {
      type = types.str;
      default = "auto";
      description = ''
        Spoken language passed to Whisper. "auto" detects per utterance (handles
        multilingual speech); set a fixed ISO code like "en" to skip detection.
      '';
    };

    gpu = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Use the GPU-accelerated (Vulkan) voxtype build (`pkgs.voxtype-vulkan`)
        for Whisper inference. Vulkan covers NVIDIA, AMD and Intel in one binary
        and falls back to CPU when no Vulkan device is present, so it is safe to
        leave on. Set false to use the CPU-only build (`pkgs.voxtype`) - e.g. to
        avoid the heavier source build on a host with no usable GPU.
      '';
    };

    preloadModel = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Pre-download the Whisper model at activation time via voxtype's
        model-loader service instead of on first recording. The fetch still needs
        network access when the loader runs, so it is off by default (a pure
        `nixos-rebuild` never blocks on the network).
      '';
    };

    # UI surfaces — on by default when dictation is enabled, each opt-out.
    indicator = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Show a recording-state segment on Waybar, driven by
        `voxtype status --follow`. Set false to keep dictation but drop the bar
        indicator.
      '';
    };

    notify = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Emit desktop notifications (mako) on recording start/stop and on
        transcription, via voxtype's built-in `[output.notification]`.
      '';
    };

    audioFeedback = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Play start/stop sound cues via voxtype's built-in `[audio.feedback]`.
      '';
    };

    statusWindow = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Bind Super+Shift+H under Hyprland to open a floating terminal streaming
        `voxtype status --follow`, and register its window rule.
      '';
    };
  };
}
