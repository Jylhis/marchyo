# Library function unit tests
# Lightweight tests using writeText instead of runCommand
{
  pkgs,
  lib,
  ...
}:
let
  # Import library functions to test

  # Test helper: create a trivial derivation that fails at eval time if assertion fails
  # Uses writeText (no sandbox spawn) instead of runCommand
  assertTest =
    name: assertion: message:
    pkgs.writeText "test-${name}" (if assertion then "pass" else throw "FAIL: ${name}: ${message}");
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
}
