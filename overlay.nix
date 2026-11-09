{ inputs }:
final: prev:
{
  # Vendored Jylhis design system files (lib/design/README.md).
  jylhis-design-src = ./lib/design;
  tinted-schemes-src = inputs.tinted-schemes;
  marchyo-wallpapers = final.callPackage ./packages/marchyo-wallpapers/package.nix { };
  marchyo-cli = final.callPackage ./packages/marchyo-cli/package.nix { };
}
// prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux (
  {
    marchyo-shell = final.callPackage ./packages/marchyo-shell/package.nix { };
    mkMarchyoShellPlugin = final.callPackage ./packages/marchyo-shell/plugin.nix { };
    plymouth-marchyo-theme = final.callPackage ./packages/plymouth-marchyo-theme/package.nix { };
    hype = final.callPackage ./packages/hype/package.nix { };
    signed = final.callPackage ./packages/signed/package.nix { };
    monologue = final.callPackage ./packages/monologue/package.nix { };
    omarchy-audio-tuner = final.callPackage ./packages/omarchy-audio-tuner/package.nix { };
    hex-dictation = final.callPackage ./packages/hex-dictation/package.nix { };
    superwhisper = final.callPackage ./packages/superwhisper/package.nix { };
    amp-desktop = final.callPackage ./packages/amp-desktop/package.nix { };
  }
  // prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "x86_64-linux") {
    gliff = final.callPackage ./packages/gliff/package.nix { };
  }
)
// {
  # Ghostty, bat and Emacs theme files of the vendored design system, at the
  # share/jylhis/<target> paths the home modules read.
  jylhis-themes = final.runCommand "jylhis-themes" { } ''
    mkdir -p $out/share/jylhis
    cp -r ${./lib/design/platforms}/{ghostty,bat,emacs} $out/share/jylhis/
  '';
}
