# The plugins.lock.json document for a shell build: what each baked plugin is
# and where it came from. Built only from passthru.marchyoPlugin attrs and each
# plugin's store path string (no IFD, no readFile of a derivation).
# packages/marchyo-shell/package.nix serializes it with builtins.toJSON into
# share/marchyo/shell/plugins.lock.json; `marchyo plugin list` reads it.
#
# Also the one place that checks the plugin set as a whole: plugin ids and
# launcher prefixes must be unique across the shell.
{ lib }:
plugins:
let
  meta = map (p: p.marchyoPlugin) plugins;
  ids = map (m: m.id) meta;
  prefixes = lib.filter (x: x != null) (map (m: m.prefix or null) meta);
  dups = xs: lib.unique (lib.filter (x: lib.count (y: y == x) xs > 1) xs);
in
assert lib.assertMsg (
  dups ids == [ ]
) "marchyo shell plugins: duplicate plugin id(s) ${lib.concatStringsSep ", " (dups ids)}";
assert lib.assertMsg (dups prefixes == [ ])
  "marchyo shell plugins: duplicate launcher prefix(es) ${lib.concatStringsSep ", " (dups prefixes)}";
{
  lockVersion = 1;
  plugins = map (p: {
    inherit (p.marchyoPlugin)
      id
      name
      version
      kinds
      entryPoints
      ;
    prefix = p.marchyoPlugin.prefix or null;
    storePath = "${p}";
    source = p.marchyoPlugin.source or null;
  }) plugins;
}
