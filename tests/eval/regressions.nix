# Regression tests for bugs found in the repo-wide review. Each test forces a
# specific lazily-evaluated config value, so it would actually fail if the bug
# were reintroduced.
{ lib, ... }:
{
  refs = {
    # boot.kernelParams is a list option. plymouth.nix's quiet-boot params must
    # MERGE with performance.nix's `mitigations=off` (on by default), not be
    # dropped. They were previously set with mkDefault, which a normal-priority
    # list definition discards wholesale.
    headless.eval-kernelparams-merge =
      c: lib.elem "quiet" c.boot.kernelParams && lib.elem "mitigations=off" c.boot.kernelParams;

    # A consumer can still drop the quiet-boot params with mkForce
    # (headless-tweaks-2 sets boot.kernelParams = mkForce [ "mitigations=off" ]).
    headless-tweaks-2.eval-kernelparams-forcible = c: !(lib.elem "quiet" c.boot.kernelParams);

    # Under the Lua config `hyprctl dispatch <arg>` runs `return hl.dispatch(<arg>)`,
    # so the legacy `dpms off` string form is a Lua syntax error and the screen
    # never blanks.
    desktop.eval-hypridle-no-legacy-dispatch =
      c:
      let
        inherit (c.home-manager.users.testuser.services.hypridle) settings;
        commands =
          lib.attrValues (lib.filterAttrs (n: _: lib.hasSuffix "_cmd" n) settings.general)
          ++ lib.concatMap (
            l:
            lib.filter lib.isString [
              (l.on-timeout or null)
              (l.on-resume or null)
            ]
          ) settings.listener;
        legacy = lib.filter (cmd: builtins.match ".*hyprctl dispatch [a-z].*" cmd != null) commands;
      in
      lib.optional (legacy != [ ]) "hypridle has legacy dispatch commands: ${toString legacy}";
  };

  refConfig.headless-tweaks-2.boot.kernelParams = lib.mkForce [ "mitigations=off" ];
}
