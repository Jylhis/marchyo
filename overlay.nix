{ inputs }:
final: prev:
{
  jylhis-design-src = inputs.jylhis-design;
  marchyo-wallpapers = final.callPackage ./packages/marchyo-wallpapers/package.nix { };
}
// prev.lib.optionalAttrs prev.stdenv.isDarwin {
  wallpapper = final.callPackage ./packages/wallpapper/package.nix {
    src = inputs.wallpapper-src;
  };
}
// prev.lib.optionalAttrs prev.stdenv.isLinux (
  (inputs.jylhis-design.overlays.default final prev)
  // {
    vicinae = inputs.vicinae.packages.${final.stdenv.hostPlatform.system}.default;
    noctalia = inputs.noctalia.packages.${final.stdenv.hostPlatform.system}.default;

    hyprmon = final.callPackage ./packages/hyprmon/package.nix { };
    plymouth-marchyo-theme = final.callPackage ./packages/plymouth-marchyo-theme/package.nix { };
  }
)
