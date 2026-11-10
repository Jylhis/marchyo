{ inputs }:
final: prev:
{
  # Vendored Jylhis design system files (lib/design/README.md).
  jylhis-design-src = ./lib/design;
  tinted-schemes-src = inputs.tinted-schemes;
  marchyo-wallpapers = final.callPackage ./packages/marchyo-wallpapers/package.nix { };
  marchyo-cli = final.callPackage ./packages/marchyo-cli/package.nix { };
}
// prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  marchyo-shell = final.callPackage ./packages/marchyo-shell/package.nix { };
  mkMarchyoShellPlugin = final.callPackage ./packages/marchyo-shell/plugin.nix { };
  plymouth-marchyo-theme = final.callPackage ./packages/plymouth-marchyo-theme/package.nix { };
}
// {
  # Ghostty, bat and Emacs theme files of the vendored design system, at the
  # share/jylhis/<target> paths the home modules read.
  jylhis-themes = final.runCommand "jylhis-themes" { } ''
    mkdir -p $out/share/jylhis
    cp -r ${./lib/design/platforms}/{ghostty,bat,emacs} $out/share/jylhis/
  '';
}
