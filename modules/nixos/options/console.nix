{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.marchyo.console.kmscon = {
    enable = mkEnableOption ''
      kmscon, a userspace KMS/DRM terminal that replaces the in-kernel virtual
      console (the gettys on tty1-ttyN).

      kmscon renders the TTY with a real font engine, so it supports
      TrueType/Nerd fonts, Unicode, and a configurable scrollback buffer that
      the kernel console cannot provide. The XKB layout from
      `marchyo.keyboard` and the font size derived from
      `marchyo.theme.fontScale` are wired in automatically'';

    fontName = mkOption {
      type = types.str;
      default = "BlexMono Nerd Font";
      example = "JetBrainsMono Nerd Font";
      description = ''
        Monospace font family kmscon renders the console with, resolved through
        fontconfig. Defaults to the Jylhis Design System mono role, which is
        already installed by `modules/nixos/fonts.nix`. Pick any other
        monospace family present in `fonts.packages`.
      '';
    };

    scrollbackLines = mkOption {
      type = types.ints.positive;
      default = 10000;
      example = 1000;
      description = ''
        Size of kmscon's scrollback buffer in lines (its `sb-size` setting).
        The in-kernel console keeps far less history; bump this for more
        scrollback or lower it to save memory per VT.
      '';
    };

    hwaccel = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Use 3D hardware acceleration (OpenGL) to render the console. When
        enabled, `hardware.graphics.enable` is turned on (the upstream module
        asserts it). Leave off for the software renderer, which is fine for a
        text console and avoids pulling the GL stack onto headless machines.
      '';
    };

    extraConfig = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.bool
          types.int
          types.str
        ]
      );
      default = { };
      example = {
        palette = "solarized";
        font-dpi = 96;
      };
      description = ''
        Extra `kmscon.conf` key/value settings merged into
        `services.kmscon.config`, for options marchyo does not expose directly.
        Booleans render as `key` / `no-key`; see {manpage}`kmscon.conf(5)`.
        Keys set here win over marchyo's derived defaults.
      '';
    };
  };
}
