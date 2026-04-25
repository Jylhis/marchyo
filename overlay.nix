{ inputs }:
final: prev:
prev.lib.optionalAttrs prev.stdenv.isLinux {
  vicinae = inputs.vicinae.packages.${final.stdenv.hostPlatform.system}.default;
  noctalia = inputs.noctalia.packages.${final.stdenv.hostPlatform.system}.default;
  worktrunk = inputs.worktrunk.packages.${final.stdenv.hostPlatform.system}.default;

  hyprmon = final.callPackage ./packages/hyprmon/package.nix { };
  plymouth-marchyo-theme = final.callPackage ./packages/plymouth-marchyo-theme/package.nix { };
}
