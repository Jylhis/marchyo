# Build-time shell plugin platform (Option A). Eval-only: proves the
# mkMarchyoShellPlugin builder wires its passthru metadata and produces a
# derivation, without forcing the (heavy) plugin/shell build.
{
  helpers,
  pkgs,
  ...
}:
let
  inherit (helpers) assertTest;

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
}
