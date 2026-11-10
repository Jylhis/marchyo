# greetd wiring for the Quickshell greeter: with the desktop on, greetd
# launches cage running marchyo-greeter (never the old tuigreet), the
# last-user cache dir exists for the greeter user, the session theme marker
# dir exists, the greeter is built in the host's theme variant, and headless
# hosts keep no greeter at all.
{ lib, ... }:
let
  # The greeter bakes the host's theme variant: a light host launches the
  # light build, a dark host the dark one. Uses the host's own `pkgs` (with
  # the marchyo overlay).
  greeterVariant =
    variant:
    { config, pkgs, ... }:
    let
      c = config;
      # Context-free strings: hasInfix builds a regex, which may not carry
      # store-path context.
      cmd = builtins.unsafeDiscardStringContext c.services.greetd.settings.default_session.command;
      greeterFor =
        v:
        builtins.unsafeDiscardStringContext (
          lib.getExe' (pkgs.marchyo-shell.override { variant = v; }) "marchyo-greeter"
        );
      other = if variant == "light" then "dark" else "light";
    in
    c.marchyo.theme.variant == variant
    && lib.hasInfix (greeterFor variant) cmd
    && !lib.hasInfix (greeterFor other) cmd;
in
{
  refs = {
    desktop = {
      eval-greeter-default =
        c:
        c.services.greetd.enable
        && lib.hasInfix "cage" c.services.greetd.settings.default_session.command
        && lib.hasInfix "marchyo-greeter" c.services.greetd.settings.default_session.command
        && !lib.hasInfix "tuigreet" c.services.greetd.settings.default_session.command
        && !c.services.greetd.useTextGreeter;

      # Last-user cache for the username prefill, owned by the greeter user (the
      # same tmpfiles idiom the nixpkgs greetd module uses for tuigreet's cache).
      eval-greeter-cache-dir =
        c: builtins.any (r: lib.hasPrefix "d '/var/cache/marchyo-greeter'" r) c.systemd.tmpfiles.rules;

      # Session theme marker dir: root:users with the sticky bit, so session users
      # can drop their theme-<user>.json, cannot replace each other's, and the
      # greeter can read.
      eval-greeter-theme-marker-dir =
        c: builtins.elem "d '/var/lib/marchyo/greeter' 1775 root users - -" c.systemd.tmpfiles.rules;

      # dark is the default variant.
      eval-greeter-dark-variant = greeterVariant "dark";
    };

    desktop-light.eval-greeter-light-variant = greeterVariant "light";

    # Headless default: no greeter, as before.
    headless.eval-greeter-off-without-desktop = c: !c.services.greetd.enable;
  };
}
