# Auto-generate module options documentation
{
  pkgs,
  lib,
  nixosModules,
  homeModules,
}:

let
  # Minimal configuration for module evaluation
  minimalNixOSConfig = {
    _module.check = false;
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "/dev/vda";
      fsType = "ext4";
    };
    system.stateVersion = "25.11";
    nixpkgs.hostPlatform = "x86_64-linux";
  };

  # Evaluate NixOS modules to extract options
  nixosEval = lib.evalModules {
    modules = [
      nixosModules
      minimalNixOSConfig
    ];
  };

  # Evaluate Home Manager modules to extract options
  homeEval = lib.evalModules {
    modules = [
      homeModules
      { _module.check = false; }
    ];
  };

  # Filter to only marchyo.* options for NixOS
  marchyoOptions =
    lib.filterAttrs (name: _: lib.hasPrefix "marchyo" name)
      nixosEval.options;

  # Generate NixOS options documentation
  nixosOptionsDoc = pkgs.nixosOptionsDoc {
    options = marchyoOptions;
    documentType = "none";
    warningsAreErrors = false;
  };

  # For Home Manager, we want to document options that are commonly used
  # Filter out internal options and focus on user-facing ones
  relevantHomeOptions = lib.filterAttrs (
    name: opt:
    (lib.hasPrefix "programs." name
      || lib.hasPrefix "services." name
      || lib.hasPrefix "home." name
      || lib.hasPrefix "xdg." name)
    && !(lib.hasPrefix "programs.home-manager" name)
    && !(lib.hasInfix "_module" name)
    && opt ? description
  ) homeEval.options;

  homeOptionsDoc = pkgs.nixosOptionsDoc {
    options = relevantHomeOptions;
    documentType = "none";
    warningsAreErrors = false;
  };

in
{
  nixos = nixosOptionsDoc.optionsCommonMark;
  home = homeOptionsDoc.optionsCommonMark;
  nixosJson = nixosOptionsDoc.optionsJSON;
  homeJson = homeOptionsDoc.optionsJSON;
}
