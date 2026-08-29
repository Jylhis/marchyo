{ inputs }:
final: prev:
{
  jylhis-design-src = inputs.jylhis-design;
  marchyo-wallpapers = final.callPackage ./packages/marchyo-wallpapers/package.nix { };
  marchyo-cli = final.callPackage ./packages/marchyo-cli/package.nix { };
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
    marchyo-shell = final.callPackage ./packages/marchyo-shell/package.nix { };
    plymouth-marchyo-theme = final.callPackage ./packages/plymouth-marchyo-theme/package.nix { };

    openviking = final.callPackage ./packages/openviking/package.nix { };
    pi = final.callPackage ./packages/pi/package.nix { };

    # wf-recorder 0.6.0 reads AVCodec::pix_fmts/sample_fmts/ch_layouts, all
    # removed in ffmpeg 9. Mirrors nixpkgs fc31aa40; drop this once
    # nixpkgs-unstable carries it: the override throws at that point, because
    # upstream renames the argument ffmpeg -> ffmpeg_8.
    wf-recorder = prev.wf-recorder.override { ffmpeg = final.ffmpeg_8; };
  }
)
