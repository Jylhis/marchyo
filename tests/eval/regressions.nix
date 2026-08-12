# Regression tests for bugs found in the repo-wide review. Each test forces a
# specific lazily-evaluated config value, so it would actually fail if the bug
# were reintroduced (plain testNixOS only forces assertions + stateVersion).
{ helpers, lib, ... }:
let
  inherit (helpers)
    testNixOSCheck
    withTestUser
    ;
in
{
  # boot.kernelParams is a list option. plymouth.nix's quiet-boot params must
  # MERGE with performance.nix's `mitigations=off` (on by default), not be
  # dropped. They were previously set with mkDefault, which a normal-priority
  # list definition discards wholesale.
  eval-kernelparams-merge = testNixOSCheck "kernelparams-merge" (
    c: lib.elem "quiet" c.boot.kernelParams && lib.elem "mitigations=off" c.boot.kernelParams
  ) (withTestUser { });

  # A consumer can still drop the quiet-boot params with mkForce.
  eval-kernelparams-forcible =
    testNixOSCheck "kernelparams-forcible" (c: !(lib.elem "quiet" c.boot.kernelParams))
      (withTestUser {
        boot.kernelParams = lib.mkForce [ "mitigations=off" ];
      });
}
