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
}
