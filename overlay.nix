{ inputs }:
final: prev:
let
  # Taken from llm-agents.nix's own package set (its nixpkgs, so its binary
  # cache hits). Each attribute is lazy: only the ones referenced evaluate.
  llmAgentsPackages = inputs.llm-agents.packages.${prev.stdenv.hostPlatform.system} or { };
  llmAgents = prev.lib.optionalAttrs (inputs ? llm-agents) (
    prev.lib.getAttrs (builtins.filter (n: llmAgentsPackages ? ${n}) [
      "herdr-app"
      "grok"
      "opencode2"
      "pi"
      "t3code-desktop"
      "hunk"
    ]) llmAgentsPackages
    // prev.lib.optionalAttrs (llmAgentsPackages ? amp) { amp-cli = llmAgentsPackages.amp; }
  );
in
{
  jylhis-design-src = inputs.jylhis-design;
  tinted-schemes-src = inputs.tinted-schemes;
  marchyo-wallpapers = final.callPackage ./packages/marchyo-wallpapers/package.nix { };
  marchyo-cli = final.callPackage ./packages/marchyo-cli/package.nix { };
  marchyo-agent-skills = final.callPackage ./packages/marchyo-agent-skills/package.nix { };
}
// prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux (
  (inputs.jylhis-design.overlays.default final prev)
  // {
    marchyo-shell = final.callPackage ./packages/marchyo-shell/package.nix { };
    marchyo-omarchy-shims = final.callPackage ./packages/marchyo-omarchy-shims/package.nix { };
    mkMarchyoShellPlugin = final.callPackage ./packages/marchyo-shell/plugin.nix { };
    # Imported omarchy plugins for the shell's compat shim. Add to
    # marchyo.shell.plugins and place by manifest id in
    # marchyo.shell.settings.bar.layout.
    marchyo-shell-plugins = {
      sbb = final.mkMarchyoShellPlugin {
        src = final.fetchgit {
          url = "https://github.com/vvkycodevv/omarchy-sbb.git";
          rev = "5b72fd0d5e1066d15b6d75dce311878a3ad30e6b";
          hash = "sha256-oUI3yD2IQJUjAmwMHrpaoxCvFhwfrJhx/V+ErDEGUFM=";
        };
        id = "vvkycodevv.sbb";
        name = "SBB";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "BarWidget.qml";
      };
      # omarchy's first-party speedtest panels, vendored in shell/compat/plugins
      # (MIT, see shell/compat/README.md). The speed test client binary
      # (/usr/lib/omarchy/speedtest) is not packaged, so a run ends in the
      # panel's error state; the plugin proves the panel kind end to end.
      omarchy-speedtest = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/speedtest;
        id = "omarchy.speedtest";
        name = "Speed Test";
        version = "1.0.0";
        kinds = [ "panel" ];
        entryPoints.panel = "Panel.qml";
        omarchyFirstParty = true;
      };
      omarchy-disk-speedtest = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/disk-speedtest;
        id = "omarchy.disk-speedtest";
        name = "Disk speed test";
        version = "1.0.0";
        kinds = [ "panel" ];
        entryPoints.panel = "Panel.qml";
        omarchyFirstParty = true;
      };
      omarchy-clock = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/clock;
        id = "omarchy.clock";
        name = "Clock";
        version = "1.0.0";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "BarWidget.qml";
        barWidget = {
          displayName = "Clock";
          description = "Date/time label with a calendar popup";
          category = "Time";
          allowMultiple = false;
        };
        omarchyFirstParty = true;
      };
      omarchy-spacer = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/spacer;
        id = "omarchy.spacer";
        name = "Spacer";
        version = "1.0.0";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "Spacer.qml";
        barWidget = {
          displayName = "Spacer";
          description = "Configurable blank space";
          category = "Layout";
          allowMultiple = true;
          settingsForm = "spacerSettings";
        };
        omarchyFirstParty = true;
      };
      omarchy-dev-gallery = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/dev-gallery;
        id = "omarchy.dev-gallery";
        name = "Dev gallery";
        version = "1.0.0";
        kinds = [ "panel" ];
        entryPoints.panel = "GalleryPanel.qml";
        replaces = [ "panel.gallery" ];
        omarchyFirstParty = true;
      };
      omarchy-menu = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/menu;
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
        replaces = [ "launcher" ];
        omarchyFirstParty = true;
      };
      omarchy-emojis = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/emojis;
        id = "omarchy.emojis";
        name = "Emojis";
        version = "1.0.0";
        kinds = [ "overlay" ];
        keepLoaded = true;
        entryPoints.overlay = "Emojis.qml";
        replaces = [ "launcher.emoji" ];
        omarchyFirstParty = true;
      };
      omarchy-clipboard = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/clipboard;
        id = "omarchy.clipboard";
        name = "Clipboard";
        version = "1.0.0";
        kinds = [ "overlay" ];
        keepLoaded = true;
        entryPoints.overlay = "Clipboard.qml";
        replaces = [ "launcher.clipboard" ];
        omarchyFirstParty = true;
      };
      omarchy-workspaces = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/workspaces;
        id = "omarchy.workspaces";
        name = "Workspaces";
        version = "1.0.0";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "Workspaces.qml";
        barWidget = {
          displayName = "Workspaces";
          description = "Workspace number indicators";
          category = "Compositor";
          allowMultiple = false;
        };
        omarchyFirstParty = true;
      };
      omarchy-active-window = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/active-window;
        id = "omarchy.active-window";
        name = "Active window";
        version = "1.0.0";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "ActiveWindow.qml";
        barWidget = {
          displayName = "Active window";
          description = "Title of the focused window";
          category = "Compositor";
          allowMultiple = false;
          defaultSection = "left";
        };
        omarchyFirstParty = true;
      };
      omarchy-tray = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/tray;
        id = "omarchy.tray";
        name = "System tray";
        version = "1.0.0";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "Tray.qml";
        barWidget = {
          displayName = "System tray";
          description = "Status notifier items";
          category = "Status";
          allowMultiple = false;
        };
        omarchyFirstParty = true;
      };
      omarchy-media = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/media;
        id = "omarchy.media";
        name = "Media";
        version = "1.0.0";
        kinds = [
          "service"
          "bar-widget"
        ];
        entryPoints = {
          service = "Service.qml";
          barWidget = "BarWidget.qml";
        };
        barWidget = {
          displayName = "Media";
          description = "MPRIS now-playing with playback controls";
          category = "Media";
          allowMultiple = false;
        };
        keepLoaded = true;
        omarchyFirstParty = true;
      };
      omarchy-polkit = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/polkit;
        id = "omarchy.polkit";
        name = "Polkit agent";
        version = "1.0.0";
        kinds = [ "service" ];
        entryPoints.service = "PolkitAgent.qml";
        keepLoaded = true;
        replaces = [ "polkit" ];
        omarchyFirstParty = true;
      };
      omarchy-network = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/network;
        id = "omarchy.network";
        name = "Network";
        version = "1.0.0";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "Panel.qml";
        inherit (final.lib.importJSON ./shell/compat/plugins/network/manifest.json) barWidget;
        replaces = [ "panel.network" ];
        omarchyFirstParty = true;
      };
      omarchy-weather = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/weather;
        id = "omarchy.weather";
        name = "Weather";
        version = "1.0.0";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "BarWidget.qml";
        inherit (final.lib.importJSON ./shell/compat/plugins/weather/manifest.json) barWidget;
        replaces = [ "panel.weather" ];
        omarchyFirstParty = true;
      };
      omarchy-tailscale = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/tailscale;
        id = "omarchy.tailscale";
        name = "Tailscale";
        version = "1.0.0";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "Panel.qml";
        inherit (final.lib.importJSON ./shell/compat/plugins/tailscale/manifest.json) barWidget;
        replaces = [ "panel.tailscale" ];
        omarchyFirstParty = true;
      };
      omarchy-elsewhen = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/elsewhen;
        id = "omarchy.elsewhen";
        name = "Elsewhen";
        version = "1.1.0";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "Panel.qml";
        inherit (final.lib.importJSON ./shell/compat/plugins/elsewhen/manifest.json) barWidget;
        replaces = [ "panel.elsewhen" ];
        omarchyFirstParty = true;
      };
      omarchy-dropbox = final.mkMarchyoShellPlugin {
        src = ./shell/compat/plugins/dropbox;
        id = "omarchy.dropbox";
        name = "Dropbox";
        version = "1.0.0";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "Panel.qml";
        inherit (final.lib.importJSON ./shell/compat/plugins/dropbox/manifest.json) barWidget;
        replaces = [ "panel.dropbox" ];
        omarchyFirstParty = true;
      };
      agent-activity = final.mkMarchyoShellPlugin {
        src = final.fetchgit {
          url = "https://github.com/angusforbes/omarchy-agent-activity-visualization.git";
          rev = "49f28ca4c96ee597e776e7f5af81fe8ba1576190";
          hash = "sha256-AO9rO3B+VBe/80x9oMx5lFr9MrWx6hTQfCyrxsA3A9k=";
        };
        id = "agf.agent-activity";
        name = "Agent Activity";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "Panel.qml";
      };
    };
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
  // llmAgents
)
// {
  # The design-system package generates its platform files (ghostty themes, gtk
  # css, bat themes, …) in-derivation, so the built package is the only source
  # for those assets: expose it on every platform. The upstream overlay is
  # Linux-only in this tree, hence the explicit callPackage here.
  jylhis-themes = final.callPackage (inputs.jylhis-design + "/nix/themes.nix") { };
}
