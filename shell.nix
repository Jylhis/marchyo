# Development shell: `nix develop` (flake) or `nix-shell` (no flakes needed).
# Without arguments, nixpkgs and treefmt-nix come from the revisions pinned
# in flake.lock.
let
  lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes;
  fetchLocked =
    name:
    let
      l = lock.${name}.locked;
    in
    fetchTarball {
      url = "https://github.com/${l.owner}/${l.repo}/archive/${l.rev}.tar.gz";
      sha256 = l.narHash;
    };
in
{
  pkgs ? import (fetchLocked "nixpkgs") { },
  treefmt ? (import (fetchLocked "treefmt-nix")).mkWrapper pkgs (import ./treefmt.nix),
}:
pkgs.mkShell {
  packages = [
    treefmt
    pkgs.nixd
    pkgs.just
    pkgs.jq
    pkgs.bun
    pkgs.nodejs
    (pkgs.callPackage ./packages/marchyo-cli/package.nix { })
    pkgs.statix
    pkgs.deadnix
    # qmlls, qmlformat, qmllint for shell/ and greeter/.
    pkgs.qt6.qtdeclarative
    # shell/dev/sandbox and shell/dev/shot.
    pkgs.grim
    pkgs.bubblewrap
    pkgs.dbus
    pkgs.glib
    pkgs.pipewire
    pkgs.wireplumber
    (pkgs.python3.withPackages (ps: [
      ps.python-dbusmock
      ps.pygobject3
    ]))
  ];

  # The sandbox resolves themed icons from the theme modules/home/gtk.nix
  # sets, not from the host profile.
  MARCHYO_SANDBOX_ICONS = "${pkgs.adwaita-icon-theme}/share:${pkgs.hicolor-icon-theme}/share";

  # `import qs.*` resolves through a `qs -> shell` alias directory so the
  # checked-in per-directory qmldirs work for qmlls and qmllint as they do for
  # the running shell. Quickshell's own tooling mirror has no qmldir files.
  shellHook = ''
    root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    mkdir -p "$root/.dev/qml-modules"
    ln -sfn "$root/shell" "$root/.dev/qml-modules/qs"
    export QML_IMPORT_PATH="$root/.dev/qml-modules:${pkgs.quickshell}/lib/qt-6/qml:${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
  '';
}
