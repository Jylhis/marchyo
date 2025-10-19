# Internal utility functions for the marchyo flake module
# These are implementation details not exposed to end users
{ lib, ... }:
{
  # Check if a system architecture is valid
  isValidSystem =
    system:
    builtins.elem system [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

  # Merge extraSpecialArgs with automatic inputs' injection
  # Ensures inputs' is always available while allowing user overrides
  mergeSpecialArgs =
    {
      inputs,
      inputs',
      userArgs ? { },
    }:
    {
      inherit inputs inputs';
    }
    // userArgs;

  # Generate hostname from attribute name or use override
  getHostname =
    {
      attrName,
      hostnameOverride,
    }:
    if hostnameOverride != null then hostnameOverride else attrName;

  # Validate system configuration before generation
  # Returns { valid = bool; errors = [ string ]; }
  validateSystemConfig =
    _name: cfg:
    let
      errors =
        lib.optional (!cfg ? system) "Missing required 'system' attribute"
        ++ lib.optional (
          cfg ? system
          && !(builtins.elem cfg.system [
            "x86_64-linux"
            "aarch64-linux"
            "x86_64-darwin"
            "aarch64-darwin"
          ])
        ) "Invalid system architecture: ${cfg.system}"
        ++ lib.optional (!cfg ? modules) "Missing 'modules' attribute"
        ++ lib.optional (cfg ? modules && !builtins.isList cfg.modules) "'modules' must be a list";
    in
    {
      valid = errors == [ ];
      inherit errors;
    };
}
