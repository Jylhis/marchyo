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
  };
}
