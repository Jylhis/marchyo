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

  # HM's gtk3 module and marchyo's gtk.colorScheme both write dconf
  # `org/gnome/desktop/interface color-scheme`; under the light variant their
  # values diverge (HM's gtk3.nix: "prefer-light" vs marchyo's mkForce), and
  # the merge throws only when the value is forced — i.e. on a real
  # `nixos-rebuild switch`, not in lazily-evaluated eval tests. Forcing the
  # value here makes the conflict a build-time failure. (Historically this
  # also caught the same collision with Stylix's gnome target, pre-retirement;
  # the marchyo-vs-HM half is what remains worth pinning.)
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

  # Runtime bat theming: a base16 scheme in marchyo.theme.themes registers a
  # generated tmTheme via programs.bat.themes so bat.nix's `bat cache --build`
  # compiles it; the Jylhis pair ships its own tmThemes and adds none here.
  eval-themes-bat-scheme =
    testNixOSCheck "themes-bat-scheme"
      (
        cfg:
        let
          themes = cfg.home-manager.users.testuser.programs.bat.themes;
        in
        # nord's generated tmTheme is registered alongside bat.nix's shipped
        # Jylhis pair (both land in bat's cache).
        themes ? nord && themes ? "jylhis-dark"
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.theme.themes = [
          "jylhis-dark"
          "jylhis-light"
          "nord"
        ];
      });

  # Runtime fzf theming: on a desktop the runtime layer sets
  # FZF_DEFAULT_OPTS_FILE (read live) and fzf.nix drops its build-time
  # `programs.fzf.colors` so the file wins.
  eval-themes-fzf-runtime =
    testNixOSCheck "themes-fzf-runtime"
      (
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
        in
        lib.hasInfix "current-theme/fzf.opts" (hm.home.sessionVariables.FZF_DEFAULT_OPTS_FILE or "")
        && (hm.programs.fzf.colors or { }) == { }
      )
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # Runtime hyprlock theming: colours come from the current-theme include,
  # sourced first, and the lock config references the hyprlang vars.
  eval-themes-hyprlock-runtime =
    testNixOSCheck "themes-hyprlock-runtime"
      (
        cfg:
        let
          hl = cfg.home-manager.users.testuser.programs.hyprlock;
        in
        hl.sourceFirst == true
        && lib.hasInfix "current-theme/hyprlock-colors.conf" (hl.settings.source or "")
        && (builtins.elemAt hl.settings.background 0).color == "$bg"
      )
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # `marchyo theme generate` inputs: the build-variant dir (the current-theme
  # pointer) ships palette.json with the full token map (syn-* included) and
  # the slot table, plus the mako/waybar/gtk templates. Read from the
  # linkFarm's `entries` passthru, so nothing is built; forcing the manifest
  # also instantiates the nord dir (and its palette.json).
  eval-themes-generate-assets =
    testNixOSCheck "themes-generate-assets"
      (
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
          buildEntries = hm.xdg.configFile."marchyo/current-theme".source.entries;
          palette = builtins.fromJSON (builtins.unsafeDiscardStringContext buildEntries."palette.json".text);
          nord = lib.findFirst (t: t.name == "nord") null (manifestOf cfg);
        in
        lib.all (f: buildEntries ? ${f}) [
          "palette.json"
          "hyprlock-colors.conf"
          "console.txt"
          "templates/mako.conf"
          "templates/waybar.css"
          "templates/gtk.css"
        ]
        && palette.tokens ? "syn-keyword"
        && palette.tokenSlots.bg == "base00"
        && lib.hasInfix "{{token:bg}}" buildEntries."templates/mako.conf".text
        && lib.hasInfix "{{shade}}" buildEntries."templates/gtk.css".text
        && nord != null
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.theme.themes = [
          "jylhis-dark"
          "nord"
        ];
      });

  # Runtime Qt theming: on a desktop the session points Qt at the gtk3
  # platform theme so Qt follows the live GTK surface (no qt5ct/qt6ct
  # config is generated anywhere).
  eval-themes-qt-follows-gtk =
    testNixOSCheck "themes-qt-follows-gtk"
      (cfg: cfg.home-manager.users.testuser.home.sessionVariables.QT_QPA_PLATFORMTHEME == "gtk3")
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # Off the desktop (no runtime layer) fzf keeps its build-time colours.
  eval-themes-fzf-nondesktop-colors =
    testNixOSCheck "themes-fzf-nondesktop-colors"
      (cfg: (cfg.home-manager.users.testuser.programs.fzf.colors or { }) != { })
      (withTestUser {
        marchyo.theme.enable = true;
      });

  # Unknown names must fail eval (the base16-scheme loader throws with a
  # marchyo.theme.themes hint).
  eval-themes-unknown-name = assertTest "themes-unknown-name" (
    !(builtins.tryEval (builtins.deepSeq (evalManifest [ "definitely-not-a-scheme" ]) true)).success
  ) "unknown theme name did not fail evaluation";

  # marchyo.theme.fontScale scales every font surface from one knob. With
  # desktop on, this also exercises the directly-themed surfaces (waybar / mako /
  # hyprlock / ghostty / gtk / console) that read the scale. 2.0x doubles the
  # base size (12 -> 24); the GNOME interface fonts (modules/home/jylhis-theme.nix,
  # previously Stylix's gnome target) carry the same math. The launcher scales
  # the same way but is asserted in tests/eval/launcher.nix, which owns its
  # font keys.
  eval-theme-fontscale =
    testNixOSCheck "theme-fontscale"
      (
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
        in
        hm.gtk.font.size == 24
        && hm.dconf.settings."org/gnome/desktop/interface".document-font-name == "Zilla Slab 23"
        && hm.dconf.settings."org/gnome/desktop/interface".monospace-font-name == "BlexMono Nerd Font 24"
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.theme.fontScale = 2.0;
      });

  # The slot-driven long tail (previously Stylix targets) is marchyo-owned:
  # lazygit/k9s/ncspot/spotify-player/gdu theme from
  # modules/generic/theme-slots.nix, the cursor is complete, and Emacs loads
  # the design system's own themes. Spot-checks jylhis-dark base05 (#d1d4dc).
  eval-theme-slot-surfaces =
    testNixOSCheck "theme-slot-surfaces"
      (
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
        in
        hm.programs.lazygit.settings.gui.theme.defaultFgColor == [ "#d1d4dc" ]
        && hm.programs.k9s.settings.ui.skin == "jylhis"
        && hm.programs.k9s.skins.jylhis.k9s.body.fgColor == "#d1d4dc"
        && (hm.xdg.configFile."gdu/gdu.yaml".text or null) != null
        && hm.home.pointerCursor.name == "Adwaita"
        && hm.home.pointerCursor.size == 24
        && lib.hasInfix "jylhis-dark" hm.programs.emacs.extraConfig
        && lib.hasInfix "load-theme" hm.programs.emacs.extraConfig
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.emacs.enable = true;
      });

  # marchyo.theme.scheme drives the slot surfaces too (the catalog palette,
  # not the Jylhis pair): nord's base05 is #e5e9f0.
  eval-theme-slot-surfaces-scheme =
    testNixOSCheck "theme-slot-surfaces-scheme"
      (
        cfg:
        cfg.home-manager.users.testuser.programs.lazygit.settings.gui.theme.defaultFgColor == [ "#e5e9f0" ]
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.theme.scheme = "nord";
      });

  # modules/darwin/home.nix imports a curated subset of modules/home; on
  # darwin there is no runtime theme layer, so those surfaces keep their
  # build-time colours. Both input trios are checked: aarch64 (unstable) and
  # x86_64 (stable 26.05). (Historically these also pinned the Stylix target
  # opt-outs; stylix is retired and marchyo owns every surface.)
  eval-themes-darwin-buildtime-colors =
    testDarwinCheckFor "aarch64-darwin" "themes-darwin-buildtime-colors"
      (
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
        in
        (hm.programs.fzf.colors or { }) != { } && hm.xdg.configFile ? "ghostty/themes/jylhis-dark"
      )
      (withDarwinTestUser { });

  eval-themes-darwin-stable-buildtime-colors =
    testDarwinCheckFor "x86_64-darwin" "themes-darwin-stable-buildtime-colors"
      (cfg: (cfg.home-manager.users.testuser.programs.fzf.colors or { }) != { })
      (withDarwinTestUser { });
}
