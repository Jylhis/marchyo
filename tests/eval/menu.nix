# marchyo.menu.entries: the default tree, per-key merging of user entries, the
# well-formedness assertions, and the rendered menu.json. desktop-tweaks adds
# the "capture.custom" entry and disables "system.reboot"; the malformed
# entries go on the shared `misconfigured` system, each case matched by its
# own entry id.
{ helpers, lib, ... }:
let
  inherit (helpers) expect;
  entries = c: c.marchyo.menu.entries;
  ids = c: lib.attrNames (entries c);
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

in
{
  refs = {
    desktop = {
      eval-menu-default-top-level =
        c: expect (lib.all (id: entries c ? ${id}) topLevel) "a top-level entry is missing";

      eval-menu-default-parents =
        c:
        expect (lib.all (id: !(lib.hasInfix "." id) || entries c ? ${parentOf id}) (
          ids c
        )) "an entry has no parent";

      eval-menu-default-providers =
        c:
        expect (lib.all (
          id:
          let
            e = (entries c).${id};
          in
          (e.action == "provider") == (e.provider != null)
        ) (ids c)) "provider and action disagree";

      # The default tree passes its own assertions (the reference check fails
      # on any failed assertion; this names the menu's part).
      eval-menu-default-assertions =
        c: lib.filter (a: !a.assertion && lib.hasPrefix "marchyo.menu" a.message) c.assertions == [ ];
    };

    desktop-tweaks = {
      eval-menu-override-merges =
        c:
        let
          e = entries c;
        in
        expect (
          e ? "capture.custom" && e."capture.custom".label == "Custom" && e ? "capture.screenshot"
        ) "the user entry did not merge with the defaults";

      eval-menu-override-field =
        c:
        expect (
          (entries c)."system.reboot".disabled && (entries c)."system.reboot".target == "marchyo reboot"
        ) "a field override lost the default fields";

      eval-menu-json-rendered =
        c:
        let
          json = builtins.fromJSON c.home-manager.users.testuser.xdg.configFile."marchyo/menu.json".text;
        in
        expect (
          json."capture.custom".target == "true"
          && json."capture.screenshot".when == null
          && json."appearance.theme".provider == "themes"
          && json."system.hibernate".when == "test -e /etc/marchyo/hibernation"
        ) "menu.json is missing or wrong";
    };
  };

  refConfig.desktop-tweaks.marchyo.menu.entries = {
    "capture.custom" = {
      label = "Custom";
      action = "exec";
      target = "true";
    };
    "system.reboot".disabled = true;
  };

  failingConfig.misconfigured.marchyo.menu.entries = {
    "nowhere.item" = {
      label = "Orphan";
      action = "exec";
      target = "true";
    };
    "capture.broken" = {
      label = "Broken";
      action = "provider";
    };
    "capture.empty" = {
      label = "Empty";
      action = "exec";
    };
    "capture.stray" = {
      label = "Stray";
      action = "exec";
      target = "true";
      provider = "apps";
    };
  };

  failing = {
    eval-menu-missing-parent = {
      on = "misconfigured";
      expect = ''"nowhere.item": parent "nowhere" is not an entry'';
    };
    eval-menu-provider-needs-provider = {
      on = "misconfigured";
      expect = ''"capture.broken": provider must be set exactly'';
    };
    eval-menu-provider-on-exec = {
      on = "misconfigured";
      expect = ''"capture.stray": provider must be set exactly'';
    };
    eval-menu-exec-needs-target = {
      on = "misconfigured";
      expect = ''"capture.empty": action "exec" needs a non-empty target'';
    };
  };
}
