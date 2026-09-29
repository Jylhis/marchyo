{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.monitors = mkOption {
    default = [ ];
    example = [
      {
        output = "eDP-1";
        mode = "2256x1504@60";
        position = "0x0";
        scale = 1.5;
      }
      {
        output = "DP-1";
        mode = "3840x2160@144";
        position = "auto-right";
        scale = 2.0;
        transform = 0;
        vrr = 1;
      }
    ];
    description = ''
      Declarative monitor layout. Each entry configures one output and is
      rendered into Hyprland's `monitor` table. When the list is empty (the
      default), marchyo keeps a single catch-all rule that auto-detects every
      connected output at its preferred mode, position, and scale 1 — the
      historical behaviour — so hosts that do not care about monitor layout
      need not set anything.

      This drives Hyprland only. Interactive, one-off tweaks are still possible
      with `hyprmon` (the monitor menu); those live-changes do not persist
      across a rebuild, whereas entries here do.
    '';
    type = types.listOf (
      types.submodule {
        options = {
          output = mkOption {
            type = types.str;
            example = "DP-1";
            description = ''
              Output connector name as Hyprland reports it (see the output of
              `hyprctl monitors`), e.g. "eDP-1", "DP-1", "HDMI-A-1". An empty
              string is Hyprland's catch-all that matches any not-yet-named
              output.
            '';
          };

          enable = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether this output is active. When false the output is disabled
              (rendered as Hyprland's `disable`), and all other fields are
              ignored.
            '';
          };

          mode = mkOption {
            type = types.str;
            default = "preferred";
            example = "2560x1440@144";
            description = ''
              Resolution and refresh rate as `WIDTHxHEIGHT@HZ`, or one of
              Hyprland's keywords `preferred` (default), `highres`, or
              `highrr`.
            '';
          };

          position = mkOption {
            type = types.str;
            default = "auto";
            example = "1920x0";
            description = ''
              Position of this output's top-left corner in the global layout as
              `Xx Y` (e.g. "1920x0"), or one of Hyprland's automatic keywords
              `auto`, `auto-right`, `auto-left`, `auto-up`, `auto-down`.
            '';
          };

          scale = mkOption {
            type = types.numbers.positive;
            default = 1.0;
            example = 1.5;
            description = ''
              Fractional scale factor applied to this output. 1.0 is unscaled;
              1.5 or 2.0 suit HiDPI panels.
            '';
          };

          transform = mkOption {
            type = types.ints.between 0 7;
            default = 0;
            example = 1;
            description = ''
              Rotation/flip, matching Hyprland's `transform` values: 0 normal,
              1 = 90°, 2 = 180°, 3 = 270°, 4-7 the flipped variants. Only
              emitted when non-zero.
            '';
          };

          vrr = mkOption {
            type = types.nullOr (types.ints.between 0 3);
            default = null;
            example = 1;
            description = ''
              Per-output variable refresh rate (adaptive sync): 0 off, 1 on,
              2 fullscreen-only, 3 fullscreen-with-video. When null (the
              default) the field is omitted and Hyprland's global `misc:vrr`
              applies.
            '';
          };

          extraSettings = mkOption {
            type = types.attrsOf (
              types.oneOf [
                types.str
                types.int
                types.float
                types.bool
              ]
            );
            default = { };
            example = {
              bitdepth = 10;
              mirror = "eDP-1";
            };
            description = ''
              Additional key/value pairs merged verbatim into this output's
              Hyprland monitor table (e.g. `bitdepth`, `mirror`, `cm`). Escape
              hatch for keys marchyo does not model as first-class options.
            '';
          };
        };
      }
    );
  };
}
