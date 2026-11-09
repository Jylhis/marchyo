{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.audio.tuner = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install `omarchy-audio-tuner`, the tools for measuring a laptop and
        authoring a speaker tuning (`measure`, `fit`, `generate`, `compare`).
        Set `profile` to apply a shipped tuning.
      '';
    };

    profile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "dell-xps-2026";
      description = ''
        Speaker tuning to apply: a PipeWire filter-chain (biquads and a
        lookahead limiter) hosted by the `marchyo-speaker-tuning` user service
        in front of the internal speaker sink, which becomes the default
        output. Shipped tunings: `dell-xps-2026`, `asus-proart-p14-n1x` and
        `asus-zenbook-a16-ux3607oa`. `null` applies none. Requires
        `audio.tuner.enable` and PipeWire. Do not run EasyEffects alongside it.
      '';
    };
  };
}
