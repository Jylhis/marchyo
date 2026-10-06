# greetd wiring for the Quickshell greeter: with the desktop on, greetd
# launches cage running marchyo-greeter (never the old tuigreet), the
# last-user cache dir exists for the greeter user, the session theme marker
# dir exists, the greeter is built in the host's theme variant, and headless
# hosts keep no greeter at all.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  ...
}:
let
  inherit (helpers) testNixOSCheck withTestUser;

  # Evaluates directly (not via testNixOSCheck) to reach the host's `pkgs`.
  testGreeterVariant =
    name: variant:
    let
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser {
            marchyo.desktop.enable = true;
            marchyo.theme.variant = variant;
          })
        ];
      };
      # Context-free strings: hasInfix builds a regex, which may not carry
      # store-path context.
      cmd = builtins.unsafeDiscardStringContext eval.config.services.greetd.settings.default_session.command;
      greeterFor =
        v:
        builtins.unsafeDiscardStringContext (
          lib.getExe' (eval.pkgs.marchyo-shell.override { variant = v; }) "marchyo-greeter"
        );
      other = if variant == "light" then "dark" else "light";
    in
    pkgs.writeText "eval-${name}" (
      if lib.hasInfix (greeterFor variant) cmd && !lib.hasInfix (greeterFor other) cmd then
        "pass"
      else
        throw "FAIL: ${name}: the greeter is not the ${variant} marchyo-shell build"
    );
in
{
  eval-greeter-default =
    testNixOSCheck "greeter-default"
      (
        c:
        c.services.greetd.enable
        && lib.hasInfix "cage" c.services.greetd.settings.default_session.command
        && lib.hasInfix "marchyo-greeter" c.services.greetd.settings.default_session.command
        && !lib.hasInfix "tuigreet" c.services.greetd.settings.default_session.command
        && !c.services.greetd.useTextGreeter
      )
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # Last-user cache for the username prefill, owned by the greeter user (the
  # same tmpfiles idiom the nixpkgs greetd module uses for tuigreet's cache).
  eval-greeter-cache-dir =
    testNixOSCheck "greeter-cache-dir"
      (c: builtins.any (r: lib.hasPrefix "d '/var/cache/marchyo-greeter'" r) c.systemd.tmpfiles.rules)
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # Session theme marker dir: root:users with the sticky bit, so session users
  # can drop theme.json, cannot replace each other's, and the greeter can read.
  eval-greeter-theme-marker-dir =
    testNixOSCheck "greeter-theme-marker-dir"
      (c: builtins.elem "d '/var/lib/marchyo/greeter' 1775 root users - -" c.systemd.tmpfiles.rules)
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # The greeter bakes the host's theme variant: a light host launches the
  # light build, a dark host the dark one.
  eval-greeter-light-variant = testGreeterVariant "greeter-light-variant" "light";
  eval-greeter-dark-variant = testGreeterVariant "greeter-dark-variant" "dark";

  # Headless default: no greeter, as before.
  eval-greeter-off-without-desktop = testNixOSCheck "greeter-off-without-desktop" (
    c: !c.services.greetd.enable
  ) (withTestUser { });
}
