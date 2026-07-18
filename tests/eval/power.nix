{ helpers, ... }:
let
  inherit (helpers) testNixOS testNixOSFails withTestUser;
in
{
  # Hibernation enabled with a resume device evaluates cleanly.
  eval-hibernation = testNixOS "hibernation" (withTestUser {
    marchyo.power.hibernation = {
      enable = true;
      resumeDevice = "/dev/disk/by-label/swap";
    };
  });

  # suspend-then-hibernate opted out still evaluates cleanly.
  eval-hibernation-no-sth = testNixOS "hibernation-no-sth" (withTestUser {
    marchyo.power.hibernation = {
      enable = true;
      resumeDevice = "/dev/disk/by-label/swap";
      suspendThenHibernate = false;
    };
  });

  # Enabling hibernation without a resume device trips the assertion.
  eval-hibernation-missing-resume-device =
    testNixOSFails "hibernation-missing-resume-device" "marchyo.power.hibernation.resumeDevice"
      (withTestUser {
        marchyo.power.hibernation.enable = true;
      });
}
