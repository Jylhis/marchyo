# setvtrgb(8) palette table from 16 console colours: three comma-separated
# lines (reds, greens, blues), each carrying the 16 colours as 0-255 decimals.
# Inputs are "rrggbb" or "#rrggbb". Used by modules/home/theme-runtime.nix to
# emit a per-theme `console.txt`. Pure string/number work, IFD-free.
{ lib }:
let
  hexByte = import ./hex-byte.nix { inherit lib; };
in
hexes:
let
  byteAt = off: h: toString (hexByte (builtins.substring off 2 (lib.removePrefix "#" h)));
  line = off: lib.concatMapStringsSep "," (byteAt off) hexes;
in
line 0 + "\n" + line 2 + "\n" + line 4 + "\n"
