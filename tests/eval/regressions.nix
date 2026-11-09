# Regression tests for bugs found in the repo-wide review. Each test forces a
# specific lazily-evaluated config value, so it would actually fail if the bug
# were reintroduced (plain testNixOS only forces assertions + stateVersion).
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
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

  # Under the Lua config `hyprctl dispatch <arg>` runs `return hl.dispatch(<arg>)`,
  # so the legacy `dpms off` string form is a Lua syntax error and the screen
  # never blanks.
  eval-hypridle-no-legacy-dispatch =
    let
      hm =
        (lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            nixosModules
            (withTestUser {
              marchyo.desktop.enable = true;
              home-manager.users.testuser.imports = [ homeManagerModules ];
            })
          ];
        }).config.home-manager.users.testuser;
      inherit (hm.services.hypridle) settings;
      commands =
        lib.attrValues (lib.filterAttrs (n: _: lib.hasSuffix "_cmd" n) settings.general)
        ++ lib.concatMap (
          l:
          lib.filter lib.isString [
            (l.on-timeout or null)
            (l.on-resume or null)
          ]
        ) settings.listener;
      legacy = lib.filter (c: builtins.match ".*hyprctl dispatch [a-z].*" c != null) commands;
    in
    assert lib.assertMsg (legacy == [ ]) "hypridle has legacy dispatch commands: ${toString legacy}";
    pkgs.writeText "eval-hypridle-no-legacy-dispatch" "pass";
}
