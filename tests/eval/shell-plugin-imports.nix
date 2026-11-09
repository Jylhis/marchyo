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

  # omarchy's first-party speedtest panel, vendored under shell/compat/plugins.
  speedtest = mkPlugin {
    src = ../../shell/compat/plugins/speedtest;
    id = "omarchy.speedtest";
    name = "Speed Test";
    version = "1.0.0";
    kinds = [ "panel" ];
    entryPoints.panel = "Panel.qml";
    omarchyFirstParty = true;
  };
  clock = mkPlugin {
    src = ../../shell/compat/plugins/clock;
    id = "omarchy.clock";
    name = "Clock";
    version = "1.0.0";
    kinds = [ "bar-widget" ];
    entryPoints.barWidget = "BarWidget.qml";
    omarchyFirstParty = true;
  };

  spacer = mkPlugin {
    src = ../../shell/compat/plugins/spacer;
    id = "omarchy.spacer";
    name = "Spacer";
    version = "1.0.0";
    kinds = [ "bar-widget" ];
    entryPoints.barWidget = "Spacer.qml";
    omarchyFirstParty = true;
  };

  devGallery = mkPlugin {
    src = ../../shell/compat/plugins/dev-gallery;
    id = "omarchy.dev-gallery";
    name = "Dev gallery";
    version = "1.0.0";
    kinds = [ "panel" ];
    entryPoints.panel = "GalleryPanel.qml";
    omarchyFirstParty = true;
  };

  menu = mkPlugin {
    src = ../../shell/compat/plugins/menu;
    id = "omarchy.menu";
    name = "Omarchy menu";
    version = "1.0.0";
    kinds = [
      "menu"
      "bar-widget"
    ];
    keepLoaded = true;
    entryPoints = {
      menu = "Menu.qml";
      barWidget = "BarWidget.qml";
    };
    barWidget = {
      displayName = "Omarchy menu";
      description = "Launches the Omarchy menu";
      category = "Compositor";
      allowMultiple = false;
    };
    omarchyFirstParty = true;
  };

  emojis = mkPlugin {
    src = ../../shell/compat/plugins/emojis;
    id = "omarchy.emojis";
    name = "Emojis";
    version = "1.0.0";
    kinds = [ "overlay" ];
    keepLoaded = true;
    entryPoints.overlay = "Emojis.qml";
    omarchyFirstParty = true;
  };

  clipboard = mkPlugin {
    src = ../../shell/compat/plugins/clipboard;
    id = "omarchy.clipboard";
    name = "Clipboard";
    version = "1.0.0";
    kinds = [ "overlay" ];
    keepLoaded = true;
    entryPoints.overlay = "Clipboard.qml";
    omarchyFirstParty = true;
  };

in
{
  eval-import-omarchy-speedtest = assertTest "import-omarchy-speedtest" (
    speedtest.marchyoPlugin.id == "omarchy.speedtest"
    && speedtest.marchyoPlugin.kinds == [ "panel" ]
    && speedtest.marchyoPlugin.entryPoints.panel == "Panel.qml"
    && speedtest ? outPath
  ) "omarchy's speedtest panel packages through mkMarchyoShellPlugin";

  eval-import-omarchy-clock = assertTest "import-omarchy-clock" (
    clock.marchyoPlugin.id == "omarchy.clock"
    && clock.marchyoPlugin.kinds == [ "bar-widget" ]
    && clock.marchyoPlugin.entryPoints.barWidget == "BarWidget.qml"
    && clock ? outPath
  ) "omarchy's clock bar widget packages through mkMarchyoShellPlugin";

  eval-import-omarchy-spacer = assertTest "import-omarchy-spacer" (
    spacer.marchyoPlugin.id == "omarchy.spacer"
    && spacer.marchyoPlugin.kinds == [ "bar-widget" ]
    && spacer.marchyoPlugin.entryPoints.barWidget == "Spacer.qml"
    && spacer ? outPath
  ) "omarchy's spacer bar widget packages through mkMarchyoShellPlugin";

  eval-import-omarchy-dev-gallery = assertTest "import-omarchy-dev-gallery" (
    devGallery.marchyoPlugin.id == "omarchy.dev-gallery"
    && devGallery.marchyoPlugin.kinds == [ "panel" ]
    && devGallery.marchyoPlugin.entryPoints.panel == "GalleryPanel.qml"
    && devGallery ? outPath
  ) "omarchy's dev gallery panel packages through mkMarchyoShellPlugin";

  eval-import-omarchy-menu = assertTest "import-omarchy-menu" (
    menu.marchyoPlugin.id == "omarchy.menu"
    &&
      menu.marchyoPlugin.kinds == [
        "menu"
        "bar-widget"
      ]
    && menu.marchyoPlugin.entryPoints.menu == "Menu.qml"
    && menu ? outPath
  ) "omarchy's menu packages through mkMarchyoShellPlugin";

  eval-import-omarchy-emojis = assertTest "import-omarchy-emojis" (
    emojis.marchyoPlugin.id == "omarchy.emojis"
    && emojis.marchyoPlugin.kinds == [ "overlay" ]
    && emojis.marchyoPlugin.entryPoints.overlay == "Emojis.qml"
    && emojis ? outPath
  ) "omarchy's emoji picker packages through mkMarchyoShellPlugin";

  eval-import-omarchy-clipboard = assertTest "import-omarchy-clipboard" (
    clipboard.marchyoPlugin.id == "omarchy.clipboard"
    && clipboard.marchyoPlugin.kinds == [ "overlay" ]
    && clipboard.marchyoPlugin.entryPoints.overlay == "Clipboard.qml"
    && clipboard ? outPath
  ) "omarchy's clipboard manager packages through mkMarchyoShellPlugin";

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
