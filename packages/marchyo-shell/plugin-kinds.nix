# The closed set of shell plugin kinds, each mapped to the manifest
# entryPoints key that carries its QML file. Pure data with no arguments, so
# plugin.nix and the platform-neutral option declarations in
# modules/nixos/options/shell.nix both import it.
{
  "bar-widget" = "barWidget";
  launcher = "launcher";
  daemon = "daemon";
}
