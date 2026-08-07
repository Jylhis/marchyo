{
  helpers,
  lib,
  pkgs,
  nixosModules,
  ...
}:
let
  inherit (helpers)
    assertTest
    testNixOS
    testNixOSCheck
    withTestUser
    ;

  # The manifest text intentionally carries store-path context (it roots
  # the theme dirs in the closure); fromJSON forbids context, so the test
  # reader discards it first.
  manifestOf =
    cfg:
    builtins.fromJSON (
      builtins.unsafeDiscardStringContext
        cfg.home-manager.users.testuser.xdg.dataFile."marchyo/themes/manifest.json".text
    );

  evalManifest =
    themes:
    manifestOf
      (lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser {
            marchyo.desktop.enable = true;
            marchyo.theme.themes = themes;
          })
        ];
      }).config;
in
{
  eval-themes = testNixOS "themes" (withTestUser {
    marchyo.theme = {
      enable = true;
      variant = "dark";
      # Custom scheme override (must exist in pkgs.base16-schemes).
      scheme = "nord";
    };
  });

  eval-themes-light = testNixOS "themes-light" (withTestUser {
    marchyo.theme = {
      enable = true;
      variant = "light";
    };
  });

  # Sheet (light) variant with desktop — catches dark-only regressions in
  # waybar / hyprland / mako / hyprlock / fzf / starship / etc.
  eval-themes-sheet = testNixOS "themes-sheet" (withTestUser {
    marchyo = {
      desktop.enable = true;
      theme = {
        enable = true;
        variant = "light";
      };
    };
  });

  # Default marchyo.theme.themes: the Jylhis pair, manifest carries both
  # with the right polarity.
  eval-themes-manifest-default =
    testNixOSCheck "themes-manifest-default"
      (
        cfg:
        let
          m = manifestOf cfg;
        in
        map (t: t.name) m == [
          "jylhis-dark"
          "jylhis-light"
        ]
        &&
          map (t: t.variant) m == [
            "dark"
            "light"
          ]
        && builtins.all (t: lib.hasPrefix builtins.storeDir t.dir) m
      )
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # A 4-theme list mixing the Jylhis pair with base16 schemes. nord declares
  # variant: "dark" in its YAML; gruvbox-dark-hard likewise — polarity flows
  # into the manifest and every scheme dir instantiates.
  eval-themes-manifest-base16 =
    testNixOSCheck "themes-manifest-base16"
      (
        cfg:
        let
          m = manifestOf cfg;
          byName = lib.listToAttrs (map (t: lib.nameValuePair t.name t) m);
        in
        builtins.length m == 4
        && byName.nord.variant == "dark"
        && byName."gruvbox-dark-hard".variant == "dark"
        && byName.nord.dir != byName."jylhis-dark".dir
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.theme.themes = [
          "jylhis-dark"
          "jylhis-light"
          "nord"
          "gruvbox-dark-hard"
        ];
      });

  # Unknown names must fail eval (the base16-scheme loader throws with a
  # marchyo.theme.themes hint).
  eval-themes-unknown-name = assertTest "themes-unknown-name" (
    !(builtins.tryEval (builtins.deepSeq (evalManifest [ "definitely-not-a-scheme" ]) true)).success
  ) "unknown theme name did not fail evaluation";

  # marchyo.theme.fontScale scales every font surface from one knob. With
  # desktop on, this also exercises the directly-themed surfaces (waybar / mako /
  # hyprlock / ghostty / gtk / console) that read the scale. 2.0x doubles the
  # stylix base sizes (12 -> 24, 10 -> 20). The launcher scales the same way but
  # is asserted in tests/eval/launcher.nix, which owns its font keys.
  eval-theme-fontscale =
    testNixOSCheck "theme-fontscale"
      (cfg: cfg.stylix.fonts.sizes.applications == 24 && cfg.stylix.fonts.sizes.desktop == 20)
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.theme.fontScale = 2.0;
      });
}
