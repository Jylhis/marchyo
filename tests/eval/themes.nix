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
    testDarwinCheckFor
    withTestUser
    withDarwinTestUser
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
      # Custom scheme override (must exist in the tinted-schemes catalog).
      scheme = "nord";
    };
  });

  eval-themes-light = testNixOS "themes-light" (withTestUser {
    marchyo.theme = {
      enable = true;
      variant = "light";
    };
  });

  # Light variant with desktop — catches dark-only regressions in
  # waybar / hyprland / mako / hyprlock / fzf / starship / etc.
  eval-themes-light-desktop = testNixOS "themes-light-desktop" (withTestUser {
    marchyo = {
      desktop.enable = true;
      theme = {
        enable = true;
        variant = "light";
      };
    };
  });

  # Stylix's `gnome` target and marchyo's gtk.colorScheme both write dconf
  # `org/gnome/desktop/interface color-scheme` at normal priority. Under the
  # dark variant both produce "prefer-dark" and merge silently; under light
  # they diverge (Stylix: "default", HM's gtk3.nix: "prefer-light") and the
  # merge throws only when the value is forced — i.e. on a real `nixos-rebuild
  # switch`, not in lazily-evaluated eval tests. Forcing the value here makes
  # the conflict a build-time failure. (Real-world report: j10s local-lab,
  # marchyo.theme.variant = "light".)
  eval-themes-light-dconf-color-scheme =
    testNixOSCheck "themes-light-dconf-color-scheme"
      (
        cfg:
        cfg.home-manager.users.testuser.dconf.settings."org/gnome/desktop/interface"."color-scheme"
        == "prefer-light"
      )
      (withTestUser {
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

  # modules/darwin/home.nix imports a curated subset of modules/home, and that
  # subset has to include ../generic/theme.nix — the module that opts out of
  # the Stylix targets marchyo themes itself. Without it, stylix's HM targets
  # and marchyo's own modules define the same options at normal priority and
  # the darwin toplevel stops evaluating with "conflicting definition values".
  # Both input trios are checked: aarch64 (unstable) and x86_64 (stable 26.05).
  eval-themes-darwin-stylix-optouts =
    testDarwinCheckFor "aarch64-darwin" "themes-darwin-stylix-optouts"
      (
        cfg:
        let
          targets = cfg.home-manager.users.testuser.stylix.targets;
        in
        !targets.bat.enable && !targets.fzf.enable && !targets.starship.enable
      )
      (withDarwinTestUser { });

  eval-themes-darwin-stable-stylix-optouts =
    testDarwinCheckFor "x86_64-darwin" "themes-darwin-stable-stylix-optouts"
      (cfg: !cfg.home-manager.users.testuser.stylix.targets.bat.enable)
      (withDarwinTestUser { });
}
