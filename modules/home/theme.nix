{
  config,
  lib,
  osConfig,
  nix-colors,
  ...
}:
let
  inherit (lib) mkIf types;
  # Access NixOS configuration if available
  cfg = if osConfig ? marchyo then osConfig.marchyo.theme else null;

  # Determine which scheme to use
  colorScheme =
    if cfg != null && cfg.scheme != null then
      # If scheme is a string, look it up in nix-colors.colorSchemes
      if builtins.isString cfg.scheme then
        nix-colors.colorSchemes.${cfg.scheme}
      else
        # Otherwise use it as a custom scheme
        cfg.scheme
    else
      # Default scheme if none specified
      nix-colors.colorSchemes.dracula;
in
{
  imports = [ nix-colors.homeManagerModules.default ];

  config = mkIf (cfg != null && cfg.enable) {
    colorScheme = colorScheme;
  };
}
