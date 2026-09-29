# Theme-catalog machinery: an inline base16 theme entry in marchyo.theme.themes
# must be materialized and appear in the runtime-switch manifest, alongside the
# Jylhis pair. Eval-only (forces the manifest text, not the asset build).
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) assertTest withTestUser;

  slotNames = map (i: "base0" + lib.substring 0 1 (lib.toUpper (lib.toHexString i))) (lib.range 0 15);
  inlineTheme = {
    name = "customcat";
    variant = "dark";
    slots = lib.genAttrs slotNames (_: "#111111");
  };

  hm =
    (lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser {
          marchyo.desktop.enable = true;
          marchyo.theme.themes = [
            "jylhis-dark"
            inlineTheme
          ];
          home-manager.users.testuser.imports = [ homeManagerModules ];
        })
      ];
    }).config.home-manager.users.testuser;

  manifest = hm.xdg.dataFile."marchyo/themes/manifest.json".text;
in
{
  eval-theme-catalog-inline = assertTest "theme-catalog-inline" (
    lib.hasInfix "\"customcat\"" manifest && lib.hasInfix "jylhis-dark" manifest
  ) "an inline base16 theme entry should appear in the runtime-switch manifest";
}
