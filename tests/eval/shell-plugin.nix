# Build-time shell plugin platform (Option A). Eval-only: proves the
# mkMarchyoShellPlugin builder wires its passthru metadata and produces a
# derivation, without forcing the (heavy) plugin/shell build.
{
  helpers,
  pkgs,
  ...
}:
let
  inherit (helpers) assertTest testNixOSCheck withTestUser;

  # A representative CLI-added plugin spec (the shape `marchyo plugin add`
  # persists into the marchyoCliState sidecar). Reading it back exercises the
  # marchyo.shell.extraPlugins submodule type without forcing the fetchgit
  # build (that only happens in the Home-Manager shell module, not in these
  # NixOS-only eval configs).
  spec = {
    id = "example.hello";
    url = "https://example.com/example-hello.git";
    rev = "0123456789abcdef0123456789abcdef01234567";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    kinds = [ "bar-widget" ];
    entryPoints = {
      barWidget = "Panel.qml";
    };
  };

  # The test harness passes a bare nixpkgs (no marchyo overlay), so build the
  # plugin straight from plugin.nix via callPackage rather than
  # pkgs.mkMarchyoShellPlugin. callPackage fills the tool args and leaves the
  # { src, id, ... } function.
  mkPlugin = pkgs.callPackage ../../packages/marchyo-shell/plugin.nix { };

  plugin = mkPlugin {
    src = ./fixtures/example-plugin;
    id = "example.hello";
    kinds = [ "bar-widget" ];
    entryPoints = {
      barWidget = "BarWidget.qml";
    };
  };
  m = plugin.marchyoPlugin;
in
{
  eval-shell-plugin-metadata = assertTest "shell-plugin-metadata" (
    m.id == "example.hello"
    && m.kinds == [ "bar-widget" ]
    && m.entryPoints.barWidget == "BarWidget.qml"
    && plugin ? outPath
  ) "mkMarchyoShellPlugin must expose passthru.marchyoPlugin and be a derivation";

  # The marchyo.* namespace is reserved: building such a plugin must abort.
  eval-shell-plugin-reserved-ns = assertTest "shell-plugin-reserved-ns" (
    !(builtins.tryEval (mkPlugin {
      src = ./fixtures/example-plugin;
      id = "marchyo.hello";
      kinds = [ "bar-widget" ];
      entryPoints = {
        barWidget = "BarWidget.qml";
      };
    })).success
  ) "mkMarchyoShellPlugin must refuse the reserved marchyo.* id namespace";

  # The CLI-owned additive option accepts a raw pinned git spec and round-trips
  # its manifest fields (darwin-neutral; no pkgs, no fetch).
  eval-shell-extra-plugins-option =
    testNixOSCheck "shell-extra-plugins-option"
      (
        cfg:
        let
          p = builtins.head cfg.marchyo.shell.extraPlugins;
        in
        builtins.length cfg.marchyo.shell.extraPlugins == 1
        && p.id == "example.hello"
        && p.rev == spec.rev
        && p.kinds == [ "bar-widget" ]
        && p.entryPoints.barWidget == "Panel.qml"
        && p.name == null
        && p.version == null
      )
      (withTestUser {
        marchyo.shell.extraPlugins = [ spec ];
      });
}
