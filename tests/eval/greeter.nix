# greetd wiring for the Quickshell greeter: with the desktop on, greetd
# launches cage running marchyo-greeter (never the old tuigreet), the
# last-user cache dir exists for the greeter user, and headless hosts keep
# no greeter at all.
{
  helpers,
  lib,
  ...
}:
let
  inherit (helpers) testNixOSCheck withTestUser;
in
{
  eval-greeter-default = testNixOSCheck "greeter-default" (c:
    c.services.greetd.enable
    && lib.hasInfix "cage" c.services.greetd.settings.default_session.command
    && lib.hasInfix "marchyo-greeter" c.services.greetd.settings.default_session.command
    && !lib.hasInfix "tuigreet" c.services.greetd.settings.default_session.command
    && !c.services.greetd.useTextGreeter
  ) (withTestUser { marchyo.desktop.enable = true; });

  # Last-user cache for the username prefill, owned by the greeter user (the
  # same tmpfiles idiom the nixpkgs greetd module uses for tuigreet's cache).
  eval-greeter-cache-dir = testNixOSCheck "greeter-cache-dir" (c:
    builtins.any (r: lib.hasPrefix "d '/var/cache/marchyo-greeter'" r) c.systemd.tmpfiles.rules
  ) (withTestUser { marchyo.desktop.enable = true; });

  # Headless default: no greeter, as before.
  eval-greeter-off-without-desktop = testNixOSCheck "greeter-off-without-desktop" (c:
    !c.services.greetd.enable
  ) (withTestUser { });
}
