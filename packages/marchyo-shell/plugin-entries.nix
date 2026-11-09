# Flattens built plugins (passthru.marchyoPlugin) into one entry per manifest:
# the plugin's own followed by its sibling manifests. Entry points are relative
# to the plugin root, `storePath` is the plugin's store path, and `parent` is
# null for a plugin's primary manifest, else the primary's id. Shared by
# plugin-lock.nix and package.nix's index generator.
{ lib }:
plugins:
lib.concatMap (
  p:
  let
    m = p.marchyoPlugin;
    base = {
      storePath = "${p}";
      source = m.source or null;
    };
    own = base // {
      inherit (m)
        id
        name
        version
        kinds
        entryPoints
        ;
      prefix = m.prefix or null;
      keepLoaded = m.keepLoaded or false;
      replaces = m.replaces or [ ];
      barWidget = m.barWidget or null;
      parent = null;
    };
    sibling =
      s:
      base
      // {
        inherit (s)
          id
          name
          version
          kinds
          entryPoints
          prefix
          keepLoaded
          replaces
          barWidget
          ;
        parent = m.id;
      };
  in
  [ own ] ++ map sibling (m.siblings or [ ])
) plugins
