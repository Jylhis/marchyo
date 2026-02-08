{ lib }:
let
  digits = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
  };
in
rec {
  # Helper: Convert hex digit to decimal
  hexDigitToDec = digit: digits.${digit};

  # Convert 2-digit hex string to decimal
  hexToDec =
    hex:
    let
      inherit (lib.strings) substring;
      high = hexDigitToDec (substring 0 1 hex);
      low = hexDigitToDec (substring 1 1 hex);
    in
    high * 16 + low;

  # Add hex prefix to a color
  withHash = color: "#${color}";

  # Convert hex color to rgb() format
  toRgb =
    color:
    let
      inherit (lib.strings) substring;
      r = hexToDec (substring 0 2 color);
      g = hexToDec (substring 2 2 color);
      b = hexToDec (substring 4 2 color);
    in
    "rgb(${toString r}, ${toString g}, ${toString b})";

  # Convert hex color to rgba() format with alpha
  toRgba =
    color: alpha:
    let
      inherit (lib.strings) substring;
      r = hexToDec (substring 0 2 color);
      g = hexToDec (substring 2 2 color);
      b = hexToDec (substring 4 2 color);
    in
    "rgba(${toString r}, ${toString g}, ${toString b}, ${alpha})";
}
