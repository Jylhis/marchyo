{ inputs }:
final: prev:
{
  jylhis-design-src = inputs.jylhis-design;
  tinted-schemes-src = inputs.tinted-schemes;
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
  }
)
// {
  # Design system 3.0.0 generates platform files (ghostty themes, gtk css,
  # bat themes, …) in-derivation; the source tree no longer commits them.
  # The built package is the only source for those assets, so expose it on
  # every platform (ghostty themes are installed on darwin too —
  # modules/home/ghostty.nix). The upstream overlay is Linux-only in this
  # tree, hence the explicit callPackage here.
  jylhis-themes = final.callPackage (inputs.jylhis-design + "/nix/themes.nix") { };
}
