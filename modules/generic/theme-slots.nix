# Base16 slot palette for the long-tail surfaces marchyo themes directly
# (lazygit, k9s, ncspot, spotify-player, gdu): the apps whose config formats
# take raw colors rather than semantic tokens. Resolves the same choice the
# retired Stylix base16Scheme made: the Jylhis pair by variant, or
# marchyo.theme.scheme from the tinted-schemes catalog. Returns
# { base00..base0F } as "#rrggbb" strings.
{
  pkgs,
  lib,
  variant ? "dark",
  scheme ? null,
}:
let
  loadScheme = import ./base16-scheme.nix {
    schemes = pkgs.tinted-schemes-src;
    inherit lib;
  };
  withHash = lib.mapAttrs (_: v: "#" + v);
  jylhis = import ./jylhis-palette.nix { inherit pkgs lib variant; };
in
if scheme != null then (loadScheme scheme).slots else withHash jylhis.base16
