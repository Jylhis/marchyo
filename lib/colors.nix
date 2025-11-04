{ lib }:
rec {
  # Add hex prefix to a color
  withHash = color: "#${color}";

  # Convert hex color to rgb() format
  toRgb =
    color:
    let
      inherit (lib.strings) toInt substring;
      r = toInt "0x${substring 0 2 color}";
      g = toInt "0x${substring 2 2 color}";
      b = toInt "0x${substring 4 2 color}";
    in
    "rgb(${toString r}, ${toString g}, ${toString b})";

  # Convert hex color to rgba() format with alpha
  toRgba =
    color: alpha:
    let
      inherit (lib.strings) toInt substring;
      r = toInt "0x${substring 0 2 color}";
      g = toInt "0x${substring 2 2 color}";
      b = toInt "0x${substring 4 2 color}";
    in
    "rgba(${toString r}, ${toString g}, ${toString b}, ${alpha})";
}
