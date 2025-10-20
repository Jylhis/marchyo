# Library function unit tests
# Tests utility functions in lib/default.nix and lib/colors.nix
{
  pkgs,
  lib,
  ...
}:
let
  # Import library functions to test
  marchyoLib = import ../lib { inherit lib; };
  inherit (marchyoLib) colors;

  # Test helper: create a derivation that validates an assertion
  # If assertion fails, the build will fail with the provided message
  assertTest =
    name: assertion: message:
    pkgs.runCommand "test-${name}" { } ''
      ${
        if assertion then
          "echo 'PASS: ${name}' > $out"
        else
          "echo 'FAIL: ${name}: ${message}' >&2 && exit 1"
      }
    '';
in
{
  # Test color utility functions
  test-colors-withHash = assertTest "colors-withHash" (
    colors.withHash "ff0000" == "#ff0000"
  ) "Expected withHash to add # prefix";

  test-colors-toRgb = assertTest "colors-toRgb" (
    colors.toRgb "ff0000" == "rgb(255, 0, 0)"
  ) "Expected toRgb to convert hex to rgb format";

  test-colors-toRgb-black = assertTest "colors-toRgb-black" (
    colors.toRgb "000000" == "rgb(0, 0, 0)"
  ) "Expected toRgb to handle black color";

  test-colors-toRgb-white = assertTest "colors-toRgb-white" (
    colors.toRgb "ffffff" == "rgb(255, 255, 255)"
  ) "Expected toRgb to handle white color";

  test-colors-toRgba = assertTest "colors-toRgba" (
    colors.toRgba "ff0000" "0.5" == "rgba(255, 0, 0, 0.5)"
  ) "Expected toRgba to convert hex to rgba format with alpha";

  test-colors-toRgba-full-opacity = assertTest "colors-toRgba-full-opacity" (
    colors.toRgba "00ff00" "1.0" == "rgba(0, 255, 0, 1.0)"
  ) "Expected toRgba to handle full opacity";

  # Test mapListToAttrs helper
  test-mapListToAttrs-simple =
    let
      result =
        marchyoLib.mapListToAttrs
          [
            "a"
            "b"
            "c"
          ]
          (name: {
            value = name;
          });
    in
    assertTest "mapListToAttrs-simple" (
      result.a.value == "a" && result.b.value == "b" && result.c.value == "c"
    ) "Expected mapListToAttrs to map list to attribute set";

  test-mapListToAttrs-empty =
    let
      result = marchyoLib.mapListToAttrs [ ] (name: {
        value = name;
      });
    in
    assertTest "mapListToAttrs-empty" (result == { }) "Expected mapListToAttrs to handle empty list";

  test-mapListToAttrs-transform =
    let
      result =
        marchyoLib.mapListToAttrs
          [
            "foo"
            "bar"
          ]
          (name: {
            uppercased = lib.toUpper name;
          });
    in
    assertTest "mapListToAttrs-transform" (
      result.foo.uppercased == "FOO" && result.bar.uppercased == "BAR"
    ) "Expected mapListToAttrs to apply transformation function";
}
