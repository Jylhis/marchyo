# Imported omarchy plugins (SBB, agent-activity), packaged for the shell's
# compat shim (shell/compat). Eval-only: proves each repo packages through
# mkMarchyoShellPlugin with the manifest id / kinds / entry points marchyo
# expects, without forcing the fetchgit + shell build. Mirrors
# tests/eval/shell-plugin.nix (the harness passes a bare nixpkgs, so build the
# plugin straight from plugin.nix via callPackage rather than the overlay's
# pkgs.mkMarchyoShellPlugin). The pins match overlay.nix's marchyo-shell-plugins.
{
  helpers,
  pkgs,
  ...
}:
let
  inherit (helpers) assertTest;

  mkPlugin = pkgs.callPackage ../../packages/marchyo-shell/plugin.nix { };

  sbb = mkPlugin {
    src = pkgs.fetchgit {
      url = "https://github.com/vvkycodevv/omarchy-sbb.git";
      rev = "5b72fd0d5e1066d15b6d75dce311878a3ad30e6b";
      hash = "sha256-oUI3yD2IQJUjAmwMHrpaoxCvFhwfrJhx/V+ErDEGUFM=";
    };
    id = "vvkycodevv.sbb";
    name = "SBB";
    kinds = [ "bar-widget" ];
    entryPoints.barWidget = "BarWidget.qml";
  };

  agentActivity = mkPlugin {
    src = pkgs.fetchgit {
      url = "https://github.com/angusforbes/omarchy-agent-activity-visualization.git";
      rev = "49f28ca4c96ee597e776e7f5af81fe8ba1576190";
      hash = "sha256-AO9rO3B+VBe/80x9oMx5lFr9MrWx6hTQfCyrxsA3A9k=";
    };
    id = "agf.agent-activity";
    name = "Agent Activity";
    kinds = [ "bar-widget" ];
    entryPoints.barWidget = "Panel.qml";
  };
in
{
  eval-import-sbb = assertTest "import-sbb" (
    sbb.marchyoPlugin.id == "vvkycodevv.sbb"
    && sbb.marchyoPlugin.kinds == [ "bar-widget" ]
    && sbb.marchyoPlugin.entryPoints.barWidget == "BarWidget.qml"
    && sbb ? outPath
  ) "SBB packages through mkMarchyoShellPlugin with its manifest metadata";

  eval-import-agent-activity = assertTest "import-agent-activity" (
    agentActivity.marchyoPlugin.id == "agf.agent-activity"
    && agentActivity.marchyoPlugin.kinds == [ "bar-widget" ]
    && agentActivity.marchyoPlugin.entryPoints.barWidget == "Panel.qml"
    && agentActivity ? outPath
  ) "agent-activity packages through mkMarchyoShellPlugin with its manifest metadata";
}
