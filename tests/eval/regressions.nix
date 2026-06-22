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

  # Tracking collectors must enumerate only ENABLED marchyo users. A disabled
  # user has no users.users entry, so reading config.users.users.<u>.home for
  # it threw "attribute missing". Force the rendered audit rules to exercise it.
  eval-tracking-disabled-user =
    testNixOSCheck "tracking-disabled-user"
      (
        c:
        let
          rules = c.security.audit.rules;
        in
        # testuser (enabled) is watched; ghost (disabled) must not appear and must
        # not crash the evaluation.
        lib.any (lib.hasInfix "/home/testuser/.config") rules && !(lib.any (lib.hasInfix "ghost") rules)
      )
      (withTestUser {
        marchyo.users.ghost = {
          enable = false;
          fullname = "Ghost User";
          email = "ghost@example.com";
        };
        marchyo.tracking = {
          enable = true;
          system.auditd = true;
        };
      });
}
