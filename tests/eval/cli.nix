{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
in
{
  # CLI module: defaults to enabled, installs `marchyo` system-wide.
  eval-cli-default = testNixOS "cli-default" (withTestUser { });

  # CLI module: explicitly disabled (no marchyo binary installed).
  eval-cli-disabled = testNixOS "cli-disabled" (withTestUser {
    marchyo.cli.enable = false;
  });

  # CLI module: marchyoCliState merges into config.marchyo.* with mkDefault.
  # Note: marchyoCliState is a top-level option (not under marchyo.*) on
  # purpose to avoid a self-cycle in cli-state.nix.
  eval-cli-with-state = testNixOS "cli-with-state" (withTestUser {
    marchyoCliState = {
      theme.variant = "light";
    };
  });
}
