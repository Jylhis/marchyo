# site/src/pages/search.astro's option table advertises a `default:` per row,
# and it has drifted from reality before (it claimed marchyo.defaults.browser
# defaults to "firefox" when the real default is "google-chrome").
#
# tests/site/option-paths-test.js guards the `declared:` paths and pins that
# one browser default by regexing the Nix source. Regexing does not generalize:
# modules/nixos/options/theme.nix declares `variant = mkOption` twice (the
# marchyo.theme.variant leaf and a nested one inside marchyo.theme.themes), so
# a source-level match picks the right block by luck, not by construction.
#
# Here the real defaults come from the evaluated option tree instead, so there
# is no parsing of Nix at all. Both sides are normalized through builtins.toJSON:
# the table spells booleans as `false` and strings as `"dark"`, which is exactly
# what toJSON renders.
{
  helpers,
  lib,
  nixosModules,
  pkgs,
  ...
}:
let
  inherit (helpers) assertTest;

  inherit
    (
      (lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          { system.stateVersion = "25.11"; }
        ];
      })
    )
    options
    ;

  searchAstro = builtins.readFile ../../site/src/pages/search.astro;

  # One `{ name: '…', type: '…', default: '…', declared: '…', … }` per line.
  rows = lib.filter (r: r != null) (
    map (
      line:
      let
        m = builtins.match ".*name: '(marchyo\\.[^']*)'.*default: '([^']*)'.*" line;
      in
      if m == null then
        null
      else
        {
          name = builtins.elemAt m 0;
          advertised = builtins.elemAt m 1;
        }
    ) (lib.splitString "\n" searchAstro)
  );

  # Rows this test cannot resolve against the NixOS option tree:
  #   - "—" marks an option with no default (nothing to compare).
  #   - `<name>` is an attrsOf placeholder, not a real attribute path.
  #   - keybindingsHelp is declared by a Home Manager module, so it is absent
  #     from the NixOS options tree. tests/site/option-paths-test.js already
  #     checks that its `declared:` path really declares the namespace.
  unresolvable =
    row:
    row.advertised == "—"
    || lib.hasInfix "<name>" row.name
    || lib.hasPrefix "marchyo.keybindingsHelp" row.name;

  comparable = lib.filter (row: !unresolvable row) rows;

  # marchyo.theme.variant -> options.marchyo.theme.variant
  optionAt = name: lib.attrByPath (lib.splitString "." name) null options;

  mismatches = lib.concatMap (
    row:
    let
      opt = optionAt row.name;
    in
    if opt == null then
      [ "${row.name}: advertised in the table but not declared in the NixOS option tree" ]
    else if !(opt ? default) then
      [ "${row.name}: the table advertises ${row.advertised} but the option declares no default" ]
    else if builtins.toJSON opt.default != row.advertised then
      [
        "${row.name}: the table says ${row.advertised}, the option defaults to ${builtins.toJSON opt.default}"
      ]
    else
      [ ]
  ) comparable;
in
{
  # A silent drop in parsed rows would make the comparison below vacuous.
  test-site-option-defaults-table-parses =
    assertTest "site-option-defaults-table-parses"
      (builtins.length rows >= 9 && builtins.length comparable >= 6)
      "Expected to parse >=9 option rows (>=6 comparable) out of site/src/pages/search.astro, got ${toString (builtins.length rows)} (${toString (builtins.length comparable)} comparable) (has the table's shape changed?)";

  test-site-option-defaults-match =
    assertTest "site-option-defaults-match" (mismatches == [ ])
      "site/src/pages/search.astro advertises defaults that the option tree does not agree with: ${builtins.concatStringsSep "; " mismatches}";
}
