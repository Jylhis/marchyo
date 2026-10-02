# Two-digit hex string -> int: "ff" -> 255, "0A" -> 10. Case-insensitive;
# throws on a non-hex digit rather than silently yielding null.
# Shared by modules/generic/base16-scheme.nix (BT.601 luminance polarity) and
# modules/home/theme-runtime.nix (rgba() literal translation).
{ lib }:
let
  hexDigit =
    c:
    lib.lists.findFirstIndex (x: x == lib.toLower c) (throw "invalid hex digit '${c}'") (
      lib.stringToCharacters "0123456789abcdef"
    );
in
s: 16 * hexDigit (builtins.substring 0 1 s) + hexDigit (builtins.substring 1 1 s)
