{ inputs }:
final: prev:
(inputs.jylhis-design.overlays.default final prev)
// {
  jylhis-design-src = inputs.jylhis-design;
}
// prev.lib.optionalAttrs prev.stdenv.isLinux {
  vicinae = inputs.vicinae.packages.${final.stdenv.hostPlatform.system}.default;
  noctalia = inputs.noctalia.packages.${final.stdenv.hostPlatform.system}.default;

  hyprmon = final.callPackage ./packages/hyprmon/package.nix { };
  plymouth-marchyo-theme = final.callPackage ./packages/plymouth-marchyo-theme/package.nix { };
  marchyo-cli = final.callPackage ./packages/marchyo-cli/package.nix { };
}
