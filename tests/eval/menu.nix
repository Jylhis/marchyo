# marchyo.menu.entries: the default tree, per-key merging of user entries, the
# well-formedness assertions, and the rendered menu.json.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;

  evalWith =
    extra:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };

  entries = extra: (evalWith extra).config.marchyo.menu.entries;
  failed = extra: lib.filter (a: !a.assertion) (evalWith extra).config.assertions;
  failsWith = extra: needle: lib.any (a: lib.hasInfix needle a.message) (failed extra);

  check =
    name: ok: detail:
    pkgs.writeText "eval-menu-${name}" (if ok then "pass" else throw "FAIL: ${name}: ${detail}");

  defaults = entries { };
  ids = lib.attrNames defaults;
  parentOf = id: lib.concatStringsSep "." (lib.init (lib.splitString "." id));
  topLevel = [
    "apps"
    "capture"
    "toggle"
    "appearance"
    "hardware"
    "system"
    "setup"
    "share"
  ];

  custom = {
    marchyo.menu.entries."capture.custom" = {
      label = "Custom";
      action = "exec";
      target = "true";
    };
  };
  orphan = {
    marchyo.menu.entries."nowhere.item" = {
      label = "Orphan";
      action = "exec";
      target = "true";
    };
  };
  providerless = {
    marchyo.menu.entries."capture.broken" = {
      label = "Broken";
      action = "provider";
    };
  };
  targetless = {
    marchyo.menu.entries."capture.empty" = {
      label = "Empty";
      action = "exec";
    };
  };
  strayProvider = {
    marchyo.menu.entries."capture.stray" = {
      label = "Stray";
      action = "exec";
      target = "true";
      provider = "apps";
    };
  };
in
{
  eval-menu-default-top-level = check "default-top-level" (lib.all (
    id: defaults ? ${id}
  ) topLevel) "a top-level entry is missing";

  eval-menu-default-parents = check "default-parents" (lib.all (
    id: !(lib.hasInfix "." id) || defaults ? ${parentOf id}
  ) ids) "an entry has no parent";

  eval-menu-default-providers = check "default-providers" (lib.all (
    id:
    let
      e = defaults.${id};
    in
    (e.action == "provider") == (e.provider != null)
  ) ids) "provider and action disagree";

  eval-menu-default-assertions = check "default-assertions" (failed { } == [ ]) "default tree fails";

  eval-menu-override-merges = check "override-merges" (
    let
      e = entries custom;
    in
    e ? "capture.custom"
    && e."capture.custom".label == "Custom"
    && e ? "capture.screenshot"
    && failed custom == [ ]
  ) "the user entry did not merge with the defaults";

  eval-menu-override-field = check "override-field" (
    (entries {
      marchyo.menu.entries."system.reboot".disabled = true;
    })."system.reboot".disabled
    &&
      (entries {
        marchyo.menu.entries."system.reboot".disabled = true;
      })."system.reboot".target == "marchyo reboot"
  ) "a field override lost the default fields";

  eval-menu-missing-parent = check "missing-parent" (failsWith orphan "is not an entry") "no failure";

  eval-menu-provider-needs-provider =
    check "provider-needs-provider" (failsWith providerless "provider must be set exactly")
      "no failure";

  eval-menu-provider-on-exec =
    check "provider-on-exec" (failsWith strayProvider "provider must be set exactly")
      "no failure";

  eval-menu-exec-needs-target =
    check "exec-needs-target" (failsWith targetless "non-empty target")
      "no failure";

  eval-menu-json-rendered = check "json-rendered" (
    let
      files = (evalWith custom).config.home-manager.users.testuser.xdg.configFile;
      json = builtins.fromJSON files."marchyo/menu.json".text;
    in
    json."capture.custom".target == "true"
    && json."capture.screenshot".when == null
    && json."appearance.theme".provider == "themes"
    && json."system.hibernate".when == "test -e /etc/marchyo/hibernation"
  ) "menu.json is missing or wrong";
}
