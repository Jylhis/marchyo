{
  lib,
  osConfig,
  nix-colors,
  colorSchemes,
  ...
}:
let
  inherit (lib) mkIf;
  # Access NixOS configuration if available
  cfg = if osConfig ? marchyo then osConfig.marchyo.theme else null;

  # Determine which scheme to use
  colorScheme =
    if cfg != null && cfg.scheme != null then
      # If scheme is a string, look it up in merged colorSchemes
      if builtins.isString cfg.scheme then
        colorSchemes.${cfg.scheme}
      else
        # Otherwise use it as a custom scheme
        cfg.scheme
    else if cfg != null && cfg.variant == "light" then
      # Default light scheme
      colorSchemes.modus-operandi-tinted
    else
      # Default dark scheme
      colorSchemes.modus-vivendi-tinted;
in
{
  imports = [ nix-colors.homeManagerModules.default ];

  config = mkIf (cfg != null && cfg.enable) {
    inherit colorScheme;
  };
}
