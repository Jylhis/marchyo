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
  manifestFileOf =
    cfg:
    builtins.fromJSON (
      builtins.unsafeDiscardStringContext
        cfg.home-manager.users.testuser.xdg.dataFile."marchyo/themes/manifest.json".text
    );
  manifestOf = cfg: (manifestFileOf cfg).themes;

  # jylhis-dark's text colour (base05) from the design tokens, with the
  # evaluated config's overlays applied (they provide jylhis-design-src, the vendored lib/design).
  darkTextOf =
    cfg:
    "#"
    + (import ../../modules/generic/jylhis-palette.nix {
      inherit lib;
      pkgs = pkgs.appendOverlays cfg.nixpkgs.overlays;
      variant = "dark";
    }).base16.base05;

  darkBgOf =
    cfg:
    "#"
    + (import ../../modules/generic/jylhis-palette.nix {
      inherit lib;
      pkgs = pkgs.appendOverlays cfg.nixpkgs.overlays;
      variant = "dark";
    }).base16.base00;

  # A desktop config with followWallpaper set to `value` (null leaves it at
  # the option default).
  evalFollow =
    value:
    (lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser {
          marchyo.desktop.enable = true;
        })
      ]
      ++ lib.optional (value != null) { marchyo.theme.followWallpaper = value; };
    }).config;

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
  # the shell / hyprland / fzf / starship / etc.
  eval-themes-light-desktop = testNixOS "themes-light-desktop" (withTestUser {
    marchyo = {
      desktop.enable = true;
      theme = {
        enable = true;
        variant = "light";
      };
    };
  });

  # The same on the marchyo.shell.enable = false fallback, which themes
  # hyprlock directly.
  eval-themes-light-desktop-shell-off = testNixOS "themes-light-desktop-shell-off" (withTestUser {
    marchyo = {
      desktop.enable = true;
      shell.enable = false;
      theme = {
        enable = true;
        variant = "light";
      };
    };
  });

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
          cli.enable = false;
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

  # marchyo.theme.followWallpaper reaches the CLI through the manifest:
  # false by default, true when set.
  eval-themes-manifest-follow-wallpaper =
    testNixOSCheck "themes-manifest-follow-wallpaper"
      (
        cfg:
        (manifestFileOf cfg).followWallpaper
        && !(manifestFileOf (evalFollow false)).followWallpaper
        && !(manifestFileOf (evalFollow null)).followWallpaper
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.theme.followWallpaper = true;
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

  # Runtime hyprlock theming (the marchyo.shell.enable = false lock): colours
  # come from the current-theme include, sourced first, and the lock config
  # references the hyprlang vars.
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
        marchyo.shell.enable = false;
      });

  # `marchyo theme generate` inputs: the build-variant dir (the current-theme
  # pointer) ships palette.json with the full token map (syn-* included) and
  # the slot table, plus the gtk template. Read from the linkFarm's `entries`
  # passthru, so nothing is built; forcing the manifest also instantiates the
  # nord dir (and its palette.json).
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
          "templates/gtk.css"
        ]
        && palette.tokens ? "syn-keyword"
        && palette.tokenSlots.bg == "base00"
        && lib.hasInfix "{{token:" buildEntries."templates/gtk.css".text
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

  # Base16-slot TUI surfaces on the runtime layer: every theme dir ships the
  # k9s skin, lazygit overlay, spotify-player theme.toml and gdu.yaml, and the
  # apps read them through the current-theme pointer (k9s/gdu/spotify-player
  # via links, lazygit via LG_CONFIG_FILE), in jylhis-dark's base05.
  eval-themes-tui-slot-surfaces =
    testNixOSCheck "themes-tui-slot-surfaces"
      (
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
          e = hm.xdg.configFile."marchyo/current-theme".source.entries;
          fg = darkTextOf cfg;
          # mkOutOfStoreSymlink: a runCommand whose build links to the target.
          linksTo =
            f: target:
            lib.hasInfix "${hm.xdg.configHome}/marchyo/current-theme/${target} " (
              hm.xdg.configFile.${f}.source.buildCommand or ""
            );
        in
        lib.hasInfix ''fgColor: "${fg}"'' e."k9s-skin.yaml".text
        && lib.hasInfix ''defaultFgColor: ["${fg}"]'' e."lazygit.yml".text
        && lib.hasInfix ''foreground = "${fg}"'' e."spotify-player-theme.toml".text
        && lib.hasInfix ''text-color: "${fg}"'' e."gdu.yaml".text
        && linksTo "k9s/skins/jylhis.yaml" "k9s-skin.yaml"
        && linksTo "gdu/gdu.yaml" "gdu.yaml"
        && linksTo "spotify-player/theme.toml" "spotify-player-theme.toml"
        && hm.programs.k9s.skins == { }
        && hm.programs.spotify-player.themes == [ ]
        && lib.hasSuffix "/current-theme/lazygit.yml" hm.home.sessionVariables.LG_CONFIG_FILE
        && lib.hasPrefix "${hm.xdg.configHome}/lazygit/config.yml," hm.home.sessionVariables.LG_CONFIG_FILE
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.defaults.musicPlayer = "spotify-player";
      });

  # With marchyo.theme.scheme the declarative (build-variant) dir carries the
  # scheme's slots, matching the build-time modules: nord's base05 is #e5e9f0.
  eval-themes-tui-slot-surfaces-scheme =
    testNixOSCheck "themes-tui-slot-surfaces-scheme"
      (
        cfg:
        let
          e = cfg.home-manager.users.testuser.xdg.configFile."marchyo/current-theme".source.entries;
        in
        lib.hasInfix ''fgColor: "#e5e9f0"'' e."k9s-skin.yaml".text
        && lib.hasInfix ''defaultFgColor: ["#e5e9f0"]'' e."lazygit.yml".text
        && lib.hasInfix ''foreground = "#e5e9f0"'' e."spotify-player-theme.toml".text
        && lib.hasInfix ''text-color: "#e5e9f0"'' e."gdu.yaml".text
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.theme.scheme = "nord";
      });

  # Build check (`just check` only evaluates it): a scheme dir resolves each
  # token through its base16 slot, so nord's palette.json and colors.json take
  # selection-bg from nord's base02 (#434c5e) and destructive from base08
  # (#bf616a), while scrim (no base16 role) keeps the Jylhis dark hex.
  build-themes-scheme-token-slots =
    let
      cfg =
        (lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            nixosModules
            (withTestUser {
              marchyo.desktop.enable = true;
              marchyo.theme.themes = [
                "jylhis-dark"
                "nord"
              ];
            })
          ];
        }).config;
      manifest =
        pkgs.writeText "themes-manifest.json"
          cfg.home-manager.users.testuser.xdg.dataFile."marchyo/themes/manifest.json".text;
    in
    pkgs.runCommand "check-themes-scheme-token-slots" { nativeBuildInputs = [ pkgs.jq ]; } ''
      jdir=$(jq -r '.themes[] | select(.name == "jylhis-dark") | .dir' ${manifest})
      ndir=$(jq -r '.themes[] | select(.name == "nord") | .dir' ${manifest})
      scrim=$(jq -r '.tokens.scrim' "$jdir/palette.json")
      jq -e '.tokens."selection-bg" == "#434c5e" and .tokens.destructive == "#bf616a"
        and .tokenSlots."selection-bg" == "base02"' "$ndir/palette.json" >/dev/null \
        || { echo "FAIL: nord palette.json selection-bg/destructive not on base02/base08"; exit 1; }
      jq -e --arg c "$scrim" '.colors.selectionBg == "#434c5e" and .colors.scrim == $c' \
        "$ndir/colors.json" >/dev/null \
        || { echo "FAIL: nord colors.json selectionBg not base02 or scrim not the Jylhis hex"; exit 1; }
      touch "$out"
    '';

  # Off the desktop (no runtime layer) the TUI surfaces keep build-time colours.
  eval-themes-tui-nondesktop-buildtime =
    testNixOSCheck "themes-tui-nondesktop-buildtime"
      (
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
          fg = darkTextOf cfg;
        in
        hm.programs.k9s.skins.jylhis.k9s.body.fgColor == fg
        && lib.hasInfix ''text-color: "${fg}"'' (hm.xdg.configFile."gdu/gdu.yaml".text or "")
        && !(hm.home.sessionVariables ? LG_CONFIG_FILE)
      )
      (withTestUser {
        marchyo.theme.enable = true;
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

  # base07 is ANSI 15 (bright white) for every base16 consumer, so the Jylhis
  # pair sets it to the token ANSI 15 (text-heading), never a ground. The
  # design's validate-tokens.mjs holds that ink at 7:1 on bg in both modes.
  # The harness pkgs has no marchyo overlay, so a module computes the check
  # with the evaluated config's pkgs and exposes it as an /etc text.
  eval-themes-base07-is-ansi15 =
    testNixOSCheck "themes-base07-is-ansi15"
      (cfg: cfg.environment.etc."marchyo-test-base07".text == "ok")
      {
        imports = [
          (withTestUser { })
          (
            { pkgs, ... }:
            let
              ok =
                variant:
                let
                  p = import ../../modules/generic/jylhis-palette.nix { inherit pkgs lib variant; };
                in
                p.base16.base07 == builtins.elemAt p.ansi16 15
                && p.base16.base07 != lib.removePrefix "#" p.hex."surface-raised";
            in
            {
              environment.etc."marchyo-test-base07".text = if ok "dark" && ok "light" then "ok" else "bad";
            }
          )
        ];
      };

  # marchyo.theme.fontScale scales every font surface from one knob. With
  # desktop on, this also exercises the directly-themed surfaces (the shell /
  # ghostty / gtk / console) that read the scale. 2.0x doubles the
  # base size (12 -> 24); the GNOME interface fonts (modules/home/jylhis-theme.nix,
  # previously Stylix's gnome target) carry the same math.
  eval-theme-fontscale =
    testNixOSCheck "theme-fontscale"
      (
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
        in
        hm.gtk.font.size == 24
        && hm.dconf.settings."org/gnome/desktop/interface".document-font-name == "Fira Sans 23"
        && hm.dconf.settings."org/gnome/desktop/interface".monospace-font-name == "IBM Plex Mono 24"
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.theme.fontScale = 2.0;
      });

  # The slot-driven long tail (previously Stylix targets) is marchyo-owned:
  # lazygit/k9s/spotify-player/gdu theme from
  # modules/generic/theme-slots.nix, the cursor is complete, and Emacs loads
  # the design system's own themes. Spot-checks jylhis-dark base05.
  eval-theme-slot-surfaces =
    testNixOSCheck "theme-slot-surfaces"
      (
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
        in
        hm.programs.lazygit.settings.gui.theme.defaultFgColor == [ (darkTextOf cfg) ]
        && hm.programs.k9s.settings.ui.skin == "jylhis"
        && hm.xdg.configFile ? "k9s/skins/jylhis.yaml"
        && hm.xdg.configFile ? "gdu/gdu.yaml"
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

  # Application surfaces on the runtime layer: the Jylhis dirs (themeDirFor)
  # carry the tmux and fcitx5 files in jylhis-dark's base05, both read them
  # through the current-theme pointer, and the fcitx5 module selects the
  # generated theme.
  eval-themes-app-surfaces =
    testNixOSCheck "themes-app-surfaces"
      (
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
          e = hm.xdg.configFile."marchyo/current-theme".source.entries;
          fg = darkTextOf cfg;
          linksTo =
            files: f: target:
            lib.hasInfix "${hm.xdg.configHome}/marchyo/current-theme/${target} " (
              files.${f}.source.buildCommand or ""
            );
          classicui = cfg.i18n.inputMethod.fcitx5.settings.addons.classicui.globalSection;
        in
        lib.hasInfix ''status-style "fg=${fg},'' e."tmux.conf".text
        && lib.hasInfix "NormalColor=${fg}" e."fcitx5-theme.conf".text
        && linksTo hm.xdg.dataFile "fcitx5/themes/marchyo/theme.conf" "fcitx5-theme.conf"
        && classicui.Theme == "marchyo"
        && lib.all (f: !(e ? ${f})) [
          "vscode-theme.json"
          "obsidian.css"
          "slack.json"
          "herdr.json"
          "preview.png"
        ]
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.tmux.enable = true;
      });

  # Build check (`just check` only evaluates it): a catalog scheme dir
  # (mkSchemeThemeDir) and an inline theme dir carry every application surface,
  # byte-identical to the generators the CLI ports (the parity fixture slots
  # for the inline dir).
  build-themes-app-surfaces =
    let
      gen = import ../../lib/theme-generators.nix { inherit lib; };
      fixture = builtins.fromJSON (
        builtins.readFile ../../packages/marchyo-cli/packages/core/tests/fixtures/theme-parity.json
      );
      cfg =
        (lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            nixosModules
            (withTestUser {
              marchyo.desktop.enable = true;
              marchyo.theme.themes = [
                "jylhis-dark"
                "nord"
                {
                  name = "inline";
                  variant = "dark";
                  slots = fixture.base16;
                }
              ];
            })
          ];
        }).config;
      manifest =
        pkgs.writeText "themes-manifest.json"
          cfg.home-manager.users.testuser.xdg.dataFile."marchyo/themes/manifest.json".text;
      files = builtins.attrNames (gen.appSurfaceTexts fixture.base16);
    in
    pkgs.runCommand "check-themes-app-surfaces" { nativeBuildInputs = [ pkgs.jq ]; } ''
      ndir=$(jq -r '.themes[] | select(.name == "nord") | .dir' ${manifest})
      idir=$(jq -r '.themes[] | select(.name == "inline") | .dir' ${manifest})
      ${lib.concatMapStrings (f: ''
        test -f "$ndir/${f}" || { echo "FAIL: nord dir lacks ${f}"; exit 1; }
        cmp ${pkgs.writeText "expected-${f}" fixture.expected.surfaces.${f}} "$idir/${f}" \
          || { echo "FAIL: inline dir ${f} differs from the generator"; exit 1; }
      '') files}
      grep -q 'status-style "fg=#e5e9f0,bg=#3b4252"' "$ndir/tmux.conf" \
        || { echo "FAIL: nord tmux.conf not on base05/base01"; exit 1; }
      touch "$out"
    '';

  # Terminal and editor surfaces: the dark build dir carries every file (foot
  # without `#`), the placeholder templates and the wallpapers dir; btop reads its theme through the current-theme pointer.
  # No Chrome policy pins a colour, so Chrome follows the portal colour scheme.
  eval-themes-editor-surfaces =
    testNixOSCheck "themes-editor-surfaces"
      (
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
          e = hm.xdg.configFile."marchyo/current-theme".source.entries;
          bg = darkBgOf cfg;
          bare = lib.removePrefix "#" bg;
        in
        lib.hasInfix ''theme[main_bg]="${bg}"'' e."btop.theme".text
        && lib.hasInfix "background ${bg}" e."kitty.conf".text
        && lib.hasInfix "background=${bare}" e."foot-theme.ini".text
        && !(lib.hasInfix "#" e."foot-theme.ini".text)
        && lib.hasInfix ''background = "${bg}"'' e."alacritty-theme.toml".text
        && lib.hasInfix ''base00 = "${bg}"'' e."helix-theme.toml".text
        && lib.hasInfix ''base00 = "${bg}"'' e."nvim-theme.lua".text
        && lib.hasInfix ''(bg "${bg}")'' e."emacs-theme.el".text
        && lib.hasInfix "{{token:bg}}" e."templates/kitty.conf".text
        && lib.hasInfix "background={{bare:bg}}" e."templates/foot-theme.ini".text
        && lib.all (f: e ? "templates/${f}") [
          "btop.theme"
          "alacritty-theme.toml"
          "helix-theme.toml"
          "nvim-theme.lua"
          "emacs-theme.el"
        ]
        && e ? wallpapers
        && hm.programs.btop.settings.color_theme == "marchyo"
        && hm.xdg.configFile ? "btop/themes/marchyo.theme"
        && !(cfg.environment.etc ? "opt/chrome/policies/managed/extra.json")
      )
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # marchyo.theme.appearance.gaps: off keeps the zero-gap grid, on gives the
  # gapped layout; the declarative value and the icon theme reach appearance.json.
  eval-themes-appearance-gaps =
    let
      hmFor =
        extra:
        (lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            nixosModules
            (withTestUser (lib.recursiveUpdate { marchyo.desktop.enable = true; } extra))
          ];
        }).config.home-manager.users.testuser;
      off = hmFor { };
      on = hmFor { marchyo.theme.appearance.gaps = true; };
      json = hm: builtins.fromJSON hm.xdg.configFile."marchyo/appearance.json".text;
      gapsIn = hm: hm.wayland.windowManager.hyprland.settings.config.general.gaps_in;
      gapsOut = hm: hm.wayland.windowManager.hyprland.settings.config.general.gaps_out;
    in
    pkgs.writeText "eval-themes-appearance-gaps" (
      if
        gapsIn off == 0
        && gapsOut off == 0
        && !(json off).gaps
        && gapsIn on == 5
        && gapsOut on == 10
        && (json on).gaps
        && (json off).iconTheme == "Adwaita"
        && lib.hasPrefix "Fira Sans " (json off).fontName
      then
        "pass"
      else
        throw "FAIL: marchyo.theme.appearance.gaps does not drive the hyprland gaps and appearance.json"
    );

  # marchyo.theme.themes.[].wallpapers: the files appear under wallpapers/ of
  # the theme dir (named by their own file name) beside the default wallpaper.png.
  build-themes-wallpapers =
    let
      extra = pkgs.writeText "extra-wall.png" "not-a-real-png";
      fixture = builtins.fromJSON (
        builtins.readFile ../../packages/marchyo-cli/packages/core/tests/fixtures/theme-parity.json
      );
      cfg =
        (lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            nixosModules
            (withTestUser {
              marchyo.desktop.enable = true;
              marchyo.theme.themes = [
                "jylhis-dark"
                "nord"
                {
                  name = "inline";
                  variant = "light";
                  slots = fixture.base16;
                  wallpapers = [ "${extra}" ];
                }
              ];
            })
          ];
        }).config;
      manifest =
        pkgs.writeText "themes-manifest.json"
          cfg.home-manager.users.testuser.xdg.dataFile."marchyo/themes/manifest.json".text;
    in
    pkgs.runCommand "check-themes-wallpapers" { nativeBuildInputs = [ pkgs.jq ]; } ''
      for name in jylhis-dark nord inline; do
        d=$(jq -r --arg n "$name" '.themes[] | select(.name == $n) | .dir' ${manifest})
        test -d "$d/wallpapers" || { echo "FAIL: $name has no wallpapers dir"; exit 1; }
      done
      d=$(jq -r '.themes[] | select(.name == "inline") | .dir' ${manifest})
      test -e "$d/wallpapers/extra-wall.png" \
        || { echo "FAIL: inline wallpapers dir lacks extra-wall.png"; exit 1; }
      d=$(jq -r '.themes[] | select(.name == "jylhis-dark") | .dir' ${manifest})
      for k in dots bands contour; do
        test -e "$d/wallpapers/jylhis-$k-dark.png" \
          || { echo "FAIL: jylhis-dark wallpapers lacks $k"; exit 1; }
      done
      test -e "$d/wallpaper.png" || { echo "FAIL: jylhis-dark lost wallpaper.png"; exit 1; }
      touch "$out"
    '';
}
