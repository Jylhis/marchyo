# Runtime theme-asset layer (modules/home/theme-runtime.nix).
#
# Eval-only: forcing the manifest text instantiates every listed theme's
# asset derivations (incl. the hex-translated mako config and waybar CSS)
# for each build-time variant, without building anything. The switching
# logic itself lives in the marchyo CLI (bun tests cover it). The one
# exception is `build-theme-runtime-assets`, a build check that materializes
# both Jylhis theme dirs and asserts their asset files and templates; `just
# check` (--no-build) only evaluates it, CI's `nix flake check` builds it.
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

  gen = import ../../lib/theme-generators.nix { inherit lib; };
  parityFixture = builtins.fromJSON (
    builtins.readFile ../../packages/marchyo-cli/packages/core/tests/fixtures/theme-parity.json
  );
  parityExpected = gen.parityExpected {
    inherit (parityFixture) base16 batThemeName;
    inherit (parityFixture.palette) tokens;
  };

  manifestText = hm: hm.xdg.dataFile."marchyo/themes/manifest.json".text or null;

  # HM's ghostty module types `settings` with formats.keyValue
  # (listsAsDuplicateKeys), whose coercedTo type wraps scalar values into
  # singleton lists on read-back — normalize to a list of strings before
  # matching (a bare hasSuffix on the raw value is a list-coercion eval error).
  ghosttyIncludes = hm: map toString (lib.toList (hm.programs.ghostty.settings.config-file or [ ]));

  # One check per build-time variant: the manifest instantiates (i.e. every
  # listed theme's assets evaluate), the current-theme pointer targets the
  # build variant's assets, ghostty reads the runtime include through it, and
  # the activation that restores runtime-repointed symlinks is ordered before
  # HM's collision check (without it, a `marchyo theme set` followed by an
  # activation fails with "would be clobbered": HM can back up foreign files
  # but not foreign symlinks).
  checkVariant =
    variant:
    let
      hm = hmFor { marchyo.theme.variant = variant; };
      manifest = manifestText hm;
      pointer = hm.xdg.configFile."marchyo/current-theme" or null;
      reset = hm.home.activation.resetThemeRuntimeSurfaces or null;
    in
    pkgs.writeText "eval-theme-runtime-${variant}" (
      if manifest == null then
        throw "FAIL: theme-runtime (${variant}): theme manifest not generated"
      else if pointer == null || !(lib.hasInfix "marchyo-theme-${variant}" (toString pointer.source)) then
        throw "FAIL: theme-runtime (${variant}): pointer missing or not targeting ${variant} assets"
      else if reset == null then
        throw "FAIL: theme-runtime (${variant}): resetThemeRuntimeSurfaces activation missing"
      else if !(lib.elem "checkLinkTargets" reset.before) then
        throw "FAIL: theme-runtime (${variant}): resetThemeRuntimeSurfaces not before checkLinkTargets"
      else if !(lib.hasInfix "marchyo/current-theme" (toString reset.data)) then
        throw "FAIL: theme-runtime (${variant}): resetThemeRuntimeSurfaces does not cover the pointer"
      else if !(lib.hasInfix "marchyo-theme-" (toString reset.data)) then
        throw "FAIL: theme-runtime (${variant}): resetThemeRuntimeSurfaces does not match manifest theme dirs"
      else if !(lib.hasInfix "generated-theme" (toString reset.data)) then
        throw "FAIL: theme-runtime (${variant}): resetThemeRuntimeSurfaces does not match the matugen generated-theme dir"
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

  # Without the desktop, the module is inert: no manifest, no pointer, no
  # ghostty include leaks into the (still evaluated) ghostty settings, and
  # no surface-reset activation runs.
  eval-theme-runtime-headless =
    let
      hm = hmFor { marchyo.desktop.enable = false; };
    in
    pkgs.writeText "eval-theme-runtime-headless" (
      if
        manifestText hm == null
        && !(hm.xdg.configFile ? "marchyo/current-theme")
        && !(hm.programs.ghostty.settings ? config-file)
        && !(hm.home.activation ? resetThemeRuntimeSurfaces)
      then
        "pass"
      else
        throw "FAIL: theme-runtime leaked the manifest, pointer, ghostty include, or surface reset without a desktop"
    );

  # The CLI's `theme generate` generators (core/src/matugen.ts) are pinned to
  # lib/theme-generators.nix through a committed fixture the bun tests read.
  # This check recomputes the fixture's `expected` from the Nix generators and
  # its `palette.tokenSlots` from the shared table; on drift, the failure
  # prints the JSON to paste back into the fixture.
  eval-theme-runtime-cli-parity-fixture = pkgs.writeText "eval-theme-runtime-cli-parity-fixture" (
    if parityFixture.palette.tokenSlots != gen.tokenSlots then
      throw "FAIL: theme-parity.json palette.tokenSlots drifted from lib/theme-generators.nix: ${builtins.toJSON gen.tokenSlots}"
    else if parityFixture.expected != parityExpected then
      throw "FAIL: theme-parity.json expected drifted from lib/theme-generators.nix: ${builtins.toJSON parityExpected}"
    else
      "pass"
  );

  # Build check (not eval-only): materialize both Jylhis theme dirs and
  # assert the runtime asset set, then fill the build dir's templates from an
  # inline base16 theme the way `marchyo theme generate` does (slot per
  # palette.json tokenSlots, else the build hex) and require byte equality with
  # the Nix-swapped surfaces of that theme's own dir. `just check` (--no-build)
  # only evaluates this; `nix flake check` / CI builds it. The pointer source
  # and manifest text carry the linkFarm context, so interpolating them into
  # the script builds the dirs.
  build-theme-runtime-assets =
    let
      darkHm = hmFor {
        marchyo.theme.themes = [
          "jylhis-dark"
          "jylhis-light"
          {
            name = "parity";
            variant = "dark";
            slots = parityFixture.base16;
          }
        ];
      };
      darkDir = darkHm.xdg.configFile."marchyo/current-theme".source;
      lightDir =
        (hmFor { marchyo.theme.variant = "light"; }).xdg.configFile."marchyo/current-theme".source;
      manifest = pkgs.writeText "theme-manifest.json" (manifestText darkHm);
      slotsJson = pkgs.writeText "parity-slots.json" (builtins.toJSON parityFixture.base16);
    in
    pkgs.runCommand "check-theme-runtime-assets" { nativeBuildInputs = [ pkgs.jq ]; } ''
      for d in ${darkDir} ${lightDir}; do
        for f in variant colors.json ghostty.conf gtk.css hyprland.conf mako.conf waybar.css \
          bat.conf fzf.opts hyprlock-colors.conf console.txt palette.json \
          k9s-skin.yaml lazygit.yml spotify-player-theme.toml gdu.yaml \
          templates/mako.conf templates/waybar.css templates/gtk.css; do
          test -f "$d/$f" || { echo "FAIL: $d/$f missing"; exit 1; }
        done
        jq -e '(.tokens | has("syn-keyword")) and (.tokenSlots.bg == "base00")' "$d/palette.json" >/dev/null \
          || { echo "FAIL: $d/palette.json lacks the full token map or tokenSlots"; exit 1; }
        # Every colour literal in a template is a placeholder, never a build hex
        # (a `#` hex run followed by an identifier char is a CSS id selector).
        if grep -En '#[0-9a-fA-F]+([^0-9A-Za-z_-]|$)' "$d"/templates/*; then
          echo "FAIL: raw hex left in $d/templates"; exit 1
        fi
      done
      grep -q '{{shade}}' ${darkDir}/templates/gtk.css \
        || { echo "FAIL: gtk template has no {{shade}} placeholder"; exit 1; }
      parity=$(jq -r '.[] | select(.name == "parity") | .dir' ${manifest})
      test -f "$parity/palette.json" || { echo "FAIL: scheme dir has no palette.json"; exit 1; }
      test ! -e "$parity/templates" || { echo "FAIL: templates outside the build-variant dir"; exit 1; }
      for f in mako.conf waybar.css gtk.css; do
        jq -nrj --rawfile t ${darkDir}/templates/$f \
          --slurpfile p ${darkDir}/palette.json --slurpfile s ${slotsJson} \
          --arg shade ${lib.escapeShellArg parityExpected.shade} '
            def resolve($p; $s; $n): if $p.tokenSlots[$n] then $s[$p.tokenSlots[$n]] else $p.tokens[$n] end;
            $p[0] as $p | $s[0] as $s
            | reduce ($p.tokens | keys[]) as $n ($t; gsub("\\{\\{token:" + $n + "\\}\\}"; resolve($p; $s; $n)))
            | gsub("\\{\\{shade\\}\\}"; $shade)' > filled
        cmp filled "$parity/$f" || { echo "FAIL: filled template $f differs from the scheme dir"; exit 1; }
      done
      # The base16-slot TUI surfaces in a scheme dir are byte-identical to what
      # `marchyo theme generate` writes for the same slots (the fixture).
      ${lib.concatMapStrings
        (f: ''
          cmp ${pkgs.writeText "expected-${f}" parityExpected.${f}} "$parity/${f}" \
            || { echo "FAIL: scheme dir ${f} differs from the parity fixture"; exit 1; }
        '')
        [
          "k9s-skin.yaml"
          "lazygit.yml"
          "spotify-player-theme.toml"
          "gdu.yaml"
        ]
      }
      # The jylhis include must name BOTH themes as a ghostty light/dark pair
      # (identical in both dirs): ghostty resolves it from the system
      # color-scheme, so the dconf write in `marchyo theme set` restyles open
      # windows instead of only new ones.
      for d in ${darkDir} ${lightDir}; do
        grep -q 'theme = dark:jylhis-dark,light:jylhis-light' "$d/ghostty.conf" \
          || { echo "FAIL: $d/ghostty.conf is not the theme pair"; exit 1; }
      done
      grep -q '"name":"jylhis-dark"' ${darkDir}/colors.json \
        || { echo "FAIL: dark colors.json name"; exit 1; }
      grep -q '"variant":"dark"' ${darkDir}/colors.json \
        || { echo "FAIL: dark colors.json variant"; exit 1; }
      grep -q '"bg":"#0c0f14"' ${darkDir}/colors.json \
        || { echo "FAIL: dark colors.json bg hex"; exit 1; }
      grep -q '"name":"jylhis-light"' ${lightDir}/colors.json \
        || { echo "FAIL: light colors.json name"; exit 1; }
      grep -q '"bg":"#f5f8fc"' ${lightDir}/colors.json \
        || { echo "FAIL: light colors.json bg hex"; exit 1; }
      grep -q '#0c0f14' ${darkDir}/gtk.css \
        || { echo "FAIL: dark gtk.css not dark-polarity"; exit 1; }
      grep -q '#f5f8fc' ${lightDir}/gtk.css \
        || { echo "FAIL: light gtk.css not light-polarity"; exit 1; }
      # The dark gtk.css derives shade_color from the text token as a decimal
      # rgba; the light copy must translate it (not keep the dark literal).
      grep -q 'rgba(42, 45, 51, 0.08)' ${lightDir}/gtk.css \
        || { echo "FAIL: light gtk.css shade_color not translated"; exit 1; }
      touch "$out"
    '';
}
