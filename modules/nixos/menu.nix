{ lib, config, ... }:
let
  entries = config.marchyo.menu.entries;
  parentOf =
    id:
    let
      parts = lib.splitString "." id;
    in
    lib.concatStringsSep "." (lib.init parts);
  hasParent = id: !(lib.hasInfix "." id) || entries ? ${parentOf id};
in
{
  # Per-field defaults: a user definition adds entries or overrides single
  # fields instead of replacing the tree.
  config.marchyo.menu.entries = lib.mapAttrs (_: lib.mapAttrs (_: lib.mkDefault)) (
    import ../../lib/menu-entries.nix
  );

  config.assertions = lib.concatLists (
    lib.mapAttrsToList (id: e: [
      {
        assertion = hasParent id;
        message = "marchyo.menu.entries.\"${id}\": parent \"${parentOf id}\" is not an entry.";
      }
      {
        assertion = (e.action == "provider") == (e.provider != null);
        message = "marchyo.menu.entries.\"${id}\": provider must be set exactly when action is \"provider\".";
      }
      {
        assertion =
          !(lib.elem e.action [
            "exec"
            "terminal"
            "launcher"
          ])
          || e.target != "";
        message = "marchyo.menu.entries.\"${id}\": action \"${e.action}\" needs a non-empty target.";
      }
    ]) entries
  );
}
