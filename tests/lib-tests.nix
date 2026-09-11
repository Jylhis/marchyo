# Library function unit tests
# Lightweight tests using writeText instead of runCommand
{
  helpers,
  lib,
  ...
}:
let
  # Shared eval-time assertion helper from tests/lib.nix
  inherit (helpers) assertTest;
in
{

  # Test lib.genAttrs (replacement for mapListToAttrs)
  test-genAttrs-simple =
    let
      result =
        lib.genAttrs
          [
            "a"
            "b"
            "c"
          ]
          (name: {
            value = name;
          });
    in
    assertTest "genAttrs-simple" (
      result.a.value == "a" && result.b.value == "b" && result.c.value == "c"
    ) "Expected lib.genAttrs to map list to attribute set";

  test-genAttrs-empty =
    let
      result = lib.genAttrs [ ] (name: {
        value = name;
      });
    in
    assertTest "genAttrs-empty" (result == { }) "Expected lib.genAttrs to handle empty list";

  test-genAttrs-transform =
    let
      result =
        lib.genAttrs
          [
            "foo"
            "bar"
          ]
          (name: {
            uppercased = lib.toUpper name;
          });
    in
    assertTest "genAttrs-transform" (
      result.foo.uppercased == "FOO" && result.bar.uppercased == "BAR"
    ) "Expected lib.genAttrs to apply transformation function";

  # font-scale helper (lib/font-scale.nix): the round-half-up multiplier behind
  # marchyo.theme.fontScale, plus the terminus PSF snapping for the TTY console.
  test-fontScale-round-125 =
    let
      fs = import ../lib/font-scale.nix {
        inherit lib;
        scale = 1.25;
      };
    in
    assertTest "fontScale-round-125" (
      fs.round 12 == 15 && fs.round 10 == 13 && fs.round 12.5 == 16 && fs.round 14 == 18
    ) "Expected fontScale 1.25 to round base sizes half-up";

  test-fontScale-round-identity =
    let
      fs = import ../lib/font-scale.nix {
        inherit lib;
        scale = 1.0;
      };
    in
    assertTest "fontScale-round-identity" (
      fs.round 12 == 12 && fs.round 10 == 10
    ) "Expected fontScale 1.0 to leave base sizes unchanged";

  test-fontScale-terminus =
    let
      fs125 = import ../lib/font-scale.nix {
        inherit lib;
        scale = 1.25;
      };
      fs10 = import ../lib/font-scale.nix {
        inherit lib;
        scale = 1.0;
      };
    in
    assertTest "fontScale-terminus" (
      fs125.terminusFont 24 == "ter-v28n" && fs10.terminusFont 24 == "ter-v24n"
    ) "Expected terminusFont to snap the scaled base to the nearest terminus PSF size";

  # modules/generic/keyboard-lib.nix: normalizeLayout must always return all
  # four keys. The attrset branch used to be a bare passthrough, so the
  # documented example below returned a value with no `variant` and no `label`
  # — contradicting the function's own doc comment.
  test-normalizeLayout-string =
    let
      inherit (import ../modules/generic/keyboard-lib.nix) normalizeLayout;
    in
    assertTest "normalizeLayout-string" (
      normalizeLayout "us" == {
        layout = "us";
        variant = "";
        ime = null;
        label = null;
      }
    ) "normalizeLayout of a bare layout code did not match the documented example";

  test-normalizeLayout-attrs =
    let
      inherit (import ../modules/generic/keyboard-lib.nix) normalizeLayout;
    in
    assertTest "normalizeLayout-attrs" (
      normalizeLayout {
        layout = "cn";
        ime = "pinyin";
      } == {
        layout = "cn";
        variant = "";
        ime = "pinyin";
        label = null;
      }
    ) "normalizeLayout of a partial attrset did not fill in variant/label";

  # Values the caller did supply must survive the merge.
  test-normalizeLayout-keeps-values =
    let
      inherit (import ../modules/generic/keyboard-lib.nix) normalizeLayout;
      result = normalizeLayout {
        layout = "fi";
        variant = "nodeadkeys";
        label = "Finnish";
      };
    in
    assertTest "normalizeLayout-keeps-values" (
      result.variant == "nodeadkeys" && result.label == "Finnish" && result.ime == null
    ) "normalizeLayout overwrote a caller-supplied field";

  # lib/camel-case.nix: kebab-case token names -> camelCase identifiers
  # (QML property names / JSON keys). Same mapping package.nix used to bake
  # Color.qml, now shared with modules/home/theme-runtime.nix's colors.json.
  test-camel-case =
    let
      toCamel = import ../lib/camel-case.nix {
        inherit lib;
      };
    in
    assertTest "camel-case" (
      toCamel "bg-subtle" == "bgSubtle"
      && toCamel "status-err" == "statusErr"
      && toCamel "selection-bg" == "selectionBg"
      && toCamel "bg" == "bg"
      && toCamel "surface-raised" == "surfaceRaised"
    ) "Expected kebab-case names to camelCase identically to package.nix's Color.qml generator";
}
