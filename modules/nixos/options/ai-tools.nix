{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.marchyo = {
    console.enable = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = ''
        Quake-style console: the `special:qconsole` workspace drops down over
        the top half of the focused monitor with a terminal in it. The first
        time it opens, the terminal runs `$AI_AGENT` (see
        `marchyo.defaults.aiAgent`) and falls back to a shell. A console with
        a single window is boxed into a centred 2:1 panel. Super+grave
        toggles it and Super+Shift+grave moves the focused window into
        it. Part of the desktop cascade: only active when
        `marchyo.desktop.enable` is set.
      '';
    };

    ai = {
      herdr = {
        enable = mkEnableOption ''
          the herdr terminal workspace manager for AI coding agents: installs
          the CLI, runs `herdr server` as a user service, binds Super+Ctrl+Return
          to open it in the terminal, and runs `herdr integration install` for
          each agent CLI that is installed'';

        desktop.enable = mkEnableOption "the herdr desktop app (`herdr-app`)";
      };

      amp = {
        enable = mkEnableOption "the Amp CLI (`amp-cli`, unfree)";

        desktop.enable = mkEnableOption "the Amp desktop app (`amp-desktop`, unfree)";
      };
    };
  };
}
