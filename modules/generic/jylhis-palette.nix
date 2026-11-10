# Jylhis Design System palette helper. Reads the design tokens through
# lib/design/nix/palette.nix (pkgs.jylhis-design-src) and exposes:
#   - base16 : { scheme, author, base00..base0F } (feeds
#              modules/generic/theme-slots.nix and theme-runtime.nix)
#   - ansi16 : 16 hex strings, ANSI escape palette for terminals that paint
#              their own background (Ghostty etc.)
#   - tty16  : 16 hex strings for the kernel TTY. Slots 0/7/15 come from
#              semantic tokens (bg/text/text-heading) so the bare TTY and any
#              greeter inheriting it stay readable in light and dark. Mirrors
#              the override in the upstream generator (scripts/generate.mjs).
#   - hex    : token-name -> "#RRGGBB", merges palette + status + syntax so
#              new tokens appear here without editing this file.
#   - ansi   : ANSI name -> "#RRGGBB".
# Design system 5.0 is single-theme: one `jylhis` theme with light and dark
# modes, per-mode values under palette/status/syntax/chart/ansi.
# The base16 slots follow design-desktop(7), by role and not by hue (the same
# mapping as BASE16 in lib/design/scripts/lib/terminal.mjs). base16 has no slot
# for the primary signal, so `primary` stays out of the scheme.
{
  pkgs,
  lib,
  variant ? "dark",
}:
let
  tokens = (import "${pkgs.jylhis-design-src}/nix/palette.nix" { inherit lib; }).theme;
  key = if variant == "dark" then "dark" else "light";
  sh = lib.removePrefix "#";

  p = tokens.palette;
  s = tokens.status;
  sy = tokens.syntax;
  c = tokens.chart;
in
{
  base16 = {
    scheme = if key == "dark" then "Jylhis Dark" else "Jylhis Light";
    author = "Markus Jylhankangas (jylhis.com)";
    base00 = sh p.bg.${key};
    base01 = sh p."bg-subtle".${key};
    base02 = sh p."selection-bg".${key};
    base03 = sh p."text-faint".${key};
    base04 = sh p."text-muted".${key};
    base05 = sh p.text.${key};
    base06 = sh p."text-heading".${key};
    # The strongest ink, not a ground: consumers paint base07 as ANSI 15
    # (bright white), so a ground here read 1.31:1 on bg (styling.md: "The
    # Lightest Foreground"). Same as the design's base16 and its ANSI 15.
    base07 = sh p."text-heading".${key};
    base08 = sh s."status-err".${key};
    base09 = sh sy."syn-number".${key};
    base0A = sh s."status-warn".${key};
    base0B = sh sy."syn-string".${key};
    base0C = sh sy."syn-type".${key};
    base0D = sh sy."syn-function".${key};
    base0E = sh sy."syn-keyword".${key};
    base0F = sh sy."syn-docstring".${key};
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

  hex = lib.mapAttrs (_: tok: tok.${key}) (p // s // sy // c);

  ansi = lib.listToAttrs (map (e: lib.nameValuePair e.name e.${key}) tokens.ansi);

  variantKey = key;
}
