# Pure-eval loader for a base16-schemes YAML (tinted-theming format).
#
# The files are uniform enough for a line-based parse — no YAML engine (and
# no import-from-derivation beyond reading the already-fetched schemes
# package):
#
#   system: "base16"
#   name: "Nord"
#   variant: "dark"          # optional in older files
#   palette:
#     base00: "#2E3440"      # optional trailing comment
#
# Returns { name; slots; variant; } where slots is base00..base0F →
# "#rrggbb" (lowercase, "#"-prefixed) and variant is "dark"|"light" — from
# the file's variant field when present, else a relative-luminance estimate
# of base00.
{ pkgs, lib }:
schemeName:
let
  path = "${pkgs.base16-schemes}/share/themes/${schemeName}.yaml";
  raw =
    if builtins.pathExists path then
      builtins.readFile path
    else
      throw "marchyo.theme.themes: unknown theme '${schemeName}' — expected jylhis-dark, jylhis-light, or a base16-schemes YAML name (no ${path})";
  lines = lib.splitString "\n" raw;

  # `  base0X: "#RRGGBB"` (comment tails tolerated).
  slotMatch = line: builtins.match ''[[:space:]]*(base0[0-9A-F]): "#?([0-9a-fA-F]{6})".*'' line;
  slotPairs = lib.concatMap (
    line:
    let
      m = slotMatch line;
    in
    if m == null then
      [ ]
    else
      [ (lib.nameValuePair (builtins.elemAt m 0) "#${lib.toLower (builtins.elemAt m 1)}") ]
  ) lines;
  slots = lib.listToAttrs slotPairs;

  fileVariant =
    let
      matches = lib.concatMap (
        line:
        let
          m = builtins.match ''variant: "(dark|light)".*'' line;
        in
        if m == null then [ ] else [ (builtins.elemAt m 0) ]
      ) lines;
    in
    if matches == [ ] then null else builtins.head matches;

  # Fallback polarity: BT.601-weighted luminance of base00 (the background).
  hexDigit =
    c:
    lib.lists.findFirstIndex (x: x == lib.toLower c) (throw "invalid hex digit '${c}'") (
      lib.stringToCharacters "0123456789abcdef"
    );
  hexByte = s: 16 * hexDigit (builtins.substring 0 1 s) + hexDigit (builtins.substring 1 1 s);
  luminanceVariant =
    hex6:
    let
      r = hexByte (builtins.substring 0 2 hex6);
      g = hexByte (builtins.substring 2 2 hex6);
      b = hexByte (builtins.substring 4 2 hex6);
    in
    if (299 * r + 587 * g + 114 * b) / 1000 < 128 then "dark" else "light";
in
assert lib.assertMsg (builtins.length slotPairs == 16)
  "base16 scheme '${schemeName}' (${path}): expected 16 palette slots, parsed ${toString (builtins.length slotPairs)}";
{
  name = schemeName;
  inherit slots;
  variant =
    if fileVariant != null then fileVariant else luminanceVariant (lib.removePrefix "#" slots.base00);
}
