# Global font-size scaling helper.
#
# Single source of truth for the `marchyo.theme.fontScale` multiplier math, so
# every text surface (stylix sizes, ghostty, waybar, mako, hyprlock, vicinae,
# GTK apps, the TTY console) scales from one number. Imported with the resolved
# scale: `import ../../lib/font-scale.nix { inherit lib; scale = fontScale; }`.
#
# `round` is round-half-up. `terminusFont` snaps a scaled base to the nearest
# available terminus PSF size (the console font is a bitmap, so only discrete
# sizes exist).
{ lib, scale }:
let
  round = base: builtins.floor (base * scale + 0.5);

  terminusSizes = [
    12
    14
    16
    18
    20
    22
    24
    28
    32
  ];
  dist = a: b: if a > b then a - b else b - a;
  nearestTerminus =
    target:
    lib.foldl' (
      best: s: if dist s target < dist best target then s else best
    ) (lib.head terminusSizes) terminusSizes;
in
{
  inherit round;
  # e.g. terminusFont 24 -> "ter-v28n" at scale 1.25
  terminusFont = base: "ter-v${toString (nearestTerminus (round base))}n";
}
