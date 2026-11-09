{ config, lib, ... }:
let
  cfg = config.marchyo.shell;

  claims =
    let
      fromManifest = m: map (role: { inherit role; id = m.id; }) (m.replaces or [ ]);
      fromPlugin = p: lib.concatMap fromManifest ([ p.marchyoPlugin ] ++ p.marchyoPlugin.siblings or [ ]);
    in
    lib.concatMap fromPlugin cfg.plugins ++ lib.concatMap fromManifest cfg.extraPlugins;

  byRole = lib.groupBy (c: c.role) claims;
  contested = lib.filterAttrs (_: cs: lib.length cs > 1) byRole;
in
{
  config.marchyo.shell.replacedRoles = lib.mapAttrs (_: cs: (lib.head cs).id) byRole;

  config.assertions = lib.mapAttrsToList (role: cs: {
    assertion = false;
    message =
      "marchyo.shell: native role '${role}' is replaced by more than one plugin: "
      + lib.concatMapStringsSep ", " (c: c.id) cs;
  }) contested;
}
