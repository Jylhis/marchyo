# Jylhis Design System — palette helper.
#
# Reads tokens.json from the upstream design system and exposes:
#   - base16   : { scheme, author, base00..base0F } for Stylix
#   - ansi16   : 16-element list of 6-digit hex strings — ANSI escape palette
#                tuned for terminal apps that paint their own bg (Ghostty etc.)
#   - tty16    : 16-element list — kernel-TTY palette. Same as ansi16 except
#                slots 0/7/15 come from semantic tokens (bg/text/text-heading)
#                so the bare TTY (slot 0 = actual background) and any greeter
#                inheriting it stay readable in both Paper and Roast variants.
#                Mirrors the override done in the upstream design generator
#                (scripts/generate.mjs) for jylhis-{paper,roast}.nix.
#   - hex      : token-name → "#RRGGBB" attrset for CSS / Hyprland use
#   - ansi     : ANSI name → "#RRGGBB" (e.g. ansi.yellow)
#
# Source of truth: ${pkgs.jylhis-design-src}/tokens.json (tracked via flake.lock).
{
  pkgs,
  lib,
  variant ? "dark",
}:
let
  tokens = builtins.fromJSON (builtins.readFile "${pkgs.jylhis-design-src}/tokens.json");
  key = if variant == "dark" then "dark" else "light";
  sh = lib.removePrefix "#";

  p = tokens.palette;
  s = tokens.status;
  sy = tokens.syntax;
in
{
  base16 = {
    scheme = if key == "dark" then "Jylhis Roast" else "Jylhis Paper";
    author = "Markus Jylhankangas (jylhis.com)";
    base00 = sh p.bg.${key};
    base01 = sh p."bg-subtle".${key};
    base02 = sh p.surface.${key};
    base03 = sh p."text-faint".${key};
    base04 = sh p."text-muted".${key};
    base05 = sh p.text.${key};
    base06 = sh p."text-heading".${key};
    base07 = sh p."surface-raised".${key};
    base08 = sh s."status-err".${key};
    base09 = sh p.accent.${key};
    base0A = sh s."status-warn".${key};
    base0B = sh sy."syn-string".${key};
    base0C = sh sy."syn-type".${key};
    base0D = sh s."status-info".${key};
    base0E = sh sy."syn-keyword".${key};
    base0F = sh p.brand.${key};
  };

  ansi16 = map (e: sh e.${key}) tokens.ansi;

  tty16 =
    let
      overrides = {
        "0" = sh p.bg.${key};
        "7" = sh p.text.${key};
        "15" = sh p."text-heading".${key};
      };
    in
    lib.imap0 (i: e: overrides.${toString i} or (sh e.${key})) tokens.ansi;

  hex = lib.mapAttrs (_: tok: tok.${key}) (p // s // sy);

  ansi = lib.listToAttrs (map (e: lib.nameValuePair e.name e.${key}) tokens.ansi);

  variantKey = key;
}
