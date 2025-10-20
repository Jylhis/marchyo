# Main coordination module for the marchyo flake
# Imports all sub-modules and integrates them into the flake-parts framework
localFlake:
{
  ...
}:
{
  imports = [
    # Option definitions for flake.marchyo.*
    ./options.nix

    # System auto-generation logic
    (import ./systems.nix { inherit localFlake; })

    # Helper functions for perSystem
    (import ./helpers.nix { inherit localFlake; })
  ];

  # Minimal default configuration
  # The actual work is done in the imported modules
  config = {
    # Ensure perSystem is defined even if helpers are disabled
    perSystem = _: { };
  };
}
