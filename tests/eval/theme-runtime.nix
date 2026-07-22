# Runtime theme-asset layer (modules/home/theme-runtime.nix).
#
# Eval-only: forcing the manifest text instantiates every listed theme's
# asset derivations (incl. the hex-translated mako config and waybar CSS)
# for each build-time variant, without building anything. The switching
# logic itself lives in the marchyo CLI (bun tests cover it).
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;

  evalWith =
    extra:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };

  hmFor = extra: (evalWith extra).config.home-manager.users.testuser;

  manifestText = hm: hm.xdg.dataFile."marchyo/themes/manifest.json".text or null;

  # HM's ghostty module types `settings` with formats.keyValue
  # (listsAsDuplicateKeys), whose coercedTo type wraps scalar values into
  # singleton lists on read-back — normalize to a list of strings before
  # matching (a bare hasSuffix on the raw value is a list-coercion eval error).
  ghosttyIncludes = hm: map toString (lib.toList (hm.programs.ghostty.settings.config-file or [ ]));

  # One check per build-time variant: the manifest instantiates (i.e. every
  # listed theme's assets evaluate), the current-theme pointer targets the
  # build variant's assets, and ghostty reads the runtime include through it.
  checkVariant =
    variant:
    let
      hm = hmFor { marchyo.theme.variant = variant; };
      manifest = manifestText hm;
      pointer = hm.xdg.configFile."marchyo/current-theme" or null;
    in
    pkgs.writeText "eval-theme-runtime-${variant}" (
      if manifest == null then
        throw "FAIL: theme-runtime (${variant}): theme manifest not generated"
      else if pointer == null || !(lib.hasInfix "marchyo-theme-${variant}" (toString pointer.source)) then
        throw "FAIL: theme-runtime (${variant}): pointer missing or not targeting ${variant} assets"
      else if
        !(lib.any (s: lib.hasSuffix "marchyo/current-theme/ghostty.conf" s) (ghosttyIncludes hm))
      then
        throw "FAIL: theme-runtime (${variant}): ghostty include not wired through current-theme"
      else
        builtins.seq (builtins.deepSeq manifest manifest) "pass"
    );
in
{
  eval-theme-runtime-dark = checkVariant "dark";
  eval-theme-runtime-light = checkVariant "light";

  # Without the desktop, the module is inert: no manifest, no pointer, and no
  # ghostty include leaks into the (still evaluated) ghostty settings.
  eval-theme-runtime-headless =
    let
      hm = hmFor { marchyo.desktop.enable = false; };
    in
    pkgs.writeText "eval-theme-runtime-headless" (
      if
        manifestText hm == null
        && !(hm.xdg.configFile ? "marchyo/current-theme")
        && !(hm.programs.ghostty.settings ? config-file)
      then
        "pass"
      else
        throw "FAIL: theme-runtime leaked the manifest, pointer, or ghostty include without a desktop"
    );
}
