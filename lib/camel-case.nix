# kebab-case -> camelCase for identifier-safe names (QML property names,
# JSON keys): "bg-subtle" -> "bgSubtle", "status-err" -> "statusErr".
# Single source for packages/marchyo-shell/package.nix's Color.qml generator
# and modules/home/theme-runtime.nix's colors.json — the two must agree on
# property names or the generated Color.qml reads undefined palette keys.
{ lib }:
name:
let
  parts = lib.splitString "-" name;
  cap = w: lib.toUpper (lib.substring 0 1 w) + lib.substring 1 (lib.stringLength w) w;
in
lib.concatStrings (lib.imap0 (i: w: if i == 0 then w else cap w) parts)
