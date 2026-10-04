# kmscon: userspace KMS/DRM console replacing the in-kernel VT gettys.
#
# Opt-in via `marchyo.console.kmscon.enable`. When on, this wires kmscon into
# the two system-wide knobs marchyo already owns: the XKB layout configured by
# modules/nixos/keyboard.nix (via `useXkbConfig`, so TTY keymaps match the rest
# of the system) and `marchyo.theme.fontScale`, the single multiplier that
# font-scale.nix already drives for every other text surface including the
# kernel console. The derived values are plain `mkDefault`s so a consumer can
# still override individual kmscon.conf keys through `extraConfig`.
{
  config,
  lib,
  ...
}:
let
  cfg = config.marchyo.console.kmscon;
  fs = import ../../lib/font-scale.nix {
    inherit lib;
    scale = config.marchyo.theme.fontScale;
  };
in
{
  config = lib.mkIf cfg.enable {
    services.kmscon = {
      enable = true;
      # Inherit services.xserver.xkb.* (set from marchyo.keyboard) so the
      # console keymap matches the graphical session.
      useXkbConfig = true;
      config = {
        font-name = cfg.fontName;
        # kmscon font-size is a point size; scale a 12pt base by the same
        # fontScale every other marchyo text surface uses.
        font-size = fs.round 12;
        sb-size = cfg.scrollbackLines;
        hwaccel = cfg.hwaccel;
      }
      // cfg.extraConfig;
    };

    # The upstream module asserts hwaccel requires a GL stack; turn it on as an
    # overridable default rather than forcing the assertion onto the consumer.
    hardware.graphics.enable = lib.mkIf cfg.hwaccel (lib.mkDefault true);
  };
}
