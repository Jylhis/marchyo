# Runtime theme-asset layer (modules/home/theme-runtime.nix).
#
# Eval-only: forcing the manifest text instantiates every listed theme's
# asset derivations (incl. the hex-translated mako config and waybar CSS)
# for each build-time variant, without building anything. The switching
# logic itself lives in the marchyo CLI (bun tests cover it). The one
# exception is `build-theme-runtime-assets`, a build check that materializes
# both Jylhis theme dirs and asserts their asset files; `just check`
# (--no-build) only evaluates it, CI's `nix flake check` builds it.
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

  # Build check (not eval-only): materialize both Jylhis theme dirs and
  # assert the runtime asset set. `just check` (--no-build) only evaluates
  # this; `nix flake check` / CI builds it. The pointer source carries the
  # linkFarm's context, so interpolating it into the script builds the dir.
  build-theme-runtime-assets =
    let
      darkDir = (hmFor { }).xdg.configFile."marchyo/current-theme".source;
      lightDir =
        (hmFor { marchyo.theme.variant = "light"; }).xdg.configFile."marchyo/current-theme".source;
    in
    pkgs.runCommand "check-theme-runtime-assets" { } ''
      for d in ${darkDir} ${lightDir}; do
        for f in variant colors.json ghostty.conf gtk.css hyprland.conf; do
          test -f "$d/$f" || { echo "FAIL: $d/$f missing"; exit 1; }
        done
      done
      # The jylhis include must name BOTH themes as a ghostty light/dark pair
      # (identical in both dirs): ghostty resolves it from the system
      # color-scheme, so the dconf write in `marchyo theme set` restyles open
      # windows instead of only new ones.
      for d in ${darkDir} ${lightDir}; do
        grep -q 'theme = dark:jylhis-field,light:jylhis-sheet' "$d/ghostty.conf" \
          || { echo "FAIL: $d/ghostty.conf is not the theme pair"; exit 1; }
      done
      grep -q '"name":"jylhis-dark"' ${darkDir}/colors.json \
        || { echo "FAIL: dark colors.json name"; exit 1; }
      grep -q '"variant":"dark"' ${darkDir}/colors.json \
        || { echo "FAIL: dark colors.json variant"; exit 1; }
      grep -q '"bg":"#0d0f14"' ${darkDir}/colors.json \
        || { echo "FAIL: dark colors.json bg hex"; exit 1; }
      grep -q '"name":"jylhis-light"' ${lightDir}/colors.json \
        || { echo "FAIL: light colors.json name"; exit 1; }
      grep -q '"bg":"#f6f8fb"' ${lightDir}/colors.json \
        || { echo "FAIL: light colors.json bg hex"; exit 1; }
      grep -q '#0d0f14' ${darkDir}/gtk.css \
        || { echo "FAIL: dark gtk.css not dark-polarity"; exit 1; }
      grep -q '#f6f8fb' ${lightDir}/gtk.css \
        || { echo "FAIL: light gtk.css not light-polarity"; exit 1; }
      touch "$out"
    '';
}
