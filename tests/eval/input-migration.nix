{ helpers, ... }:
let
  inherit (helpers) testNixOSFails withTestUser;
in
{
  # The removed marchyo.inputMethod.enable must fail evaluation with a migration
  # message (enforced by modules/nixos/input-migration.nix).
  eval-fail-input-method-removed =
    testNixOSFails "input-method-removed" "no longer supported"
      (withTestUser {
        marchyo.inputMethod.enable = true;
      });
}
