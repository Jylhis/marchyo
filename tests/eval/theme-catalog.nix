# Theme-catalog machinery: an inline base16 theme entry in marchyo.theme.themes
# must be materialized and appear in the runtime-switch manifest, alongside the
# Jylhis pair. Eval-only (forces the manifest text, not the asset build).
# desktop-tweaks-4's theme list (tests/eval/themes.nix) carries the inline
# theme "customcat".
{ helpers, lib, ... }:
{
  refs.desktop-tweaks-4.eval-theme-catalog-inline =
    c:
    let
      manifest = c.home-manager.users.testuser.xdg.dataFile."marchyo/themes/manifest.json".text;
    in
    helpers.expect (
      lib.hasInfix "\"customcat\"" manifest && lib.hasInfix "jylhis-dark" manifest
    ) "an inline base16 theme entry should appear in the runtime-switch manifest";
}
