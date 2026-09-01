{ inputs }:
final: prev:
{
  jylhis-design-src = inputs.jylhis-design;
  marchyo-wallpapers = final.callPackage ./packages/marchyo-wallpapers/package.nix { };
  marchyo-cli = final.callPackage ./packages/marchyo-cli/package.nix { };
}
// prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  wallpapper = final.callPackage ./packages/wallpapper/package.nix {
    src = inputs.wallpapper-src;
  };
}
// prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux (
  (inputs.jylhis-design.overlays.default final prev)
  // {
    vicinae = inputs.vicinae.packages.${final.stdenv.hostPlatform.system}.default;
    noctalia = inputs.noctalia.packages.${final.stdenv.hostPlatform.system}.default;

    hyprmon = final.callPackage ./packages/hyprmon/package.nix { };
    marchyo-shell = final.callPackage ./packages/marchyo-shell/package.nix { };
    plymouth-marchyo-theme = final.callPackage ./packages/plymouth-marchyo-theme/package.nix { };

    openviking = final.callPackage ./packages/openviking/package.nix { };
    pi = final.callPackage ./packages/pi/package.nix { };
  }
)
