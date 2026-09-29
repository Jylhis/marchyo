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
    # Builder for a Marchyo shell plugin (build-time Option A). callPackage
    # fills the tool args, leaving the `{ src, id, kinds, entryPoints, ... }`
    # function as pkgs.mkMarchyoShellPlugin.
    mkMarchyoShellPlugin = final.callPackage ./packages/marchyo-shell/plugin.nix { };
    # Imported omarchy plugins, packaged for the shell's compat shim
    # (shell/compat). Pinned + baked; add to marchyo.shell.plugins and place by
    # manifest id in marchyo.shell.settings.bar.layout.
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
