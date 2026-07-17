{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;
in
{
  # Build the Hyprland config and run hyprland --verify-config against it.
  check-home-hyprland-config =
    let
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser {
            marchyo.desktop.enable = true;
            home-manager.users.testuser = {
              imports = [ homeManagerModules ];
            };
          })
        ];
      };
      hyprlandConfig = eval.config.home-manager.users.testuser.xdg.configFile."hypr/hyprland.conf".source;
      hyprland = eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.package;
    in
    pkgs.runCommand "check-hyprland-config"
      {
        nativeBuildInputs = [ hyprland ];
      }
      ''
        export XDG_RUNTIME_DIR="$(mktemp -d)"
        log=$(mktemp)
        ${hyprland}/bin/hyprland --verify-config --config ${hyprlandConfig} 2>&1 | tee "$log"

        # `--verify-config` exits 0 even when it would otherwise print
        # config errors, so also grep for any error markers it emits.
        # NOTE: In current Hyprland (0.55.x) `--verify-config` does NOT
        # report unknown dispatchers (e.g. `togglesplit`) or unknown
        # options (e.g. `dwindle:pseudotile`) — those only surface via
        # `hyprctl configerrors` on a live compositor. This grep is
        # defense-in-depth for anything that *is* printed (parser errors
        # in newer versions, malformed bind syntax, etc.).
        if grep -E -i \
             -e 'invalid dispatcher' \
             -e 'config option <[^>]+> does not exist' \
             -e '^\s*error' \
             -e 'parse error' \
             "$log"; then
          echo "FAIL: hyprland --verify-config reported config errors (see above)" >&2
          exit 1
        fi

        echo "DONE"
        touch $out
      '';

  eval-hyprland-keybindings-cheatsheet =
    let
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser {
            marchyo.desktop.enable = true;
            home-manager.users.testuser = {
              imports = [ homeManagerModules ];
            };
          })
        ];
      };
      hm = eval.config.home-manager.users.testuser;
      bindd = hm.wayland.windowManager.hyprland.settings.bindd;
      hasBind = lib.any (b: lib.hasInfix "marchyo-keybindings" b) bindd;
      hasPkg = lib.any (p: lib.hasInfix "marchyo-keybindings" (p.name or "")) hm.home.packages;
    in
    pkgs.writeText "eval-hyprland-keybindings-cheatsheet" (
      if hasBind && hasPkg then
        "pass"
      else
        throw "FAIL: keybindings cheat sheet bind or package missing when desktop enabled"
    );

  eval-hyprland-keybindings-cheatsheet-disabled =
    let
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser {
            marchyo.desktop.enable = true;
            home-manager.users.testuser = {
              imports = [ homeManagerModules ];
              marchyo.keybindingsHelp.enable = false;
            };
          })
        ];
      };
      bindd = eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bindd;
      hasBind = lib.any (b: lib.hasInfix "marchyo-keybindings" b) bindd;
    in
    pkgs.writeText "eval-hyprland-keybindings-cheatsheet-disabled" (
      if hasBind then throw "FAIL: keybindings cheat sheet bind present when disabled" else "pass"
    );

  # The omarchy-style window-management + toggle binds land on desktop and are
  # backed by the window-toggles.nix wrappers.
  eval-hyprland-window-management-binds =
    let
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser {
            marchyo.desktop.enable = true;
            home-manager.users.testuser = {
              imports = [ homeManagerModules ];
            };
          })
        ];
      };
      hm = eval.config.home-manager.users.testuser;
      bindd = hm.wayland.windowManager.hyprland.settings.bindd;
      bind = hm.wayland.windowManager.hyprland.settings.bind;
      hasBindd = needle: lib.any (b: lib.hasInfix needle b) bindd;
      hasPkg = name: lib.any (p: lib.hasInfix name (p.name or "")) hm.home.packages;

      # New window-management dispatchers are present.
      newBinds = [
        "togglegroup"
        "moveintogroup"
        "movetoworkspacesilent"
        "movecurrentworkspacetomonitor"
        "resizeactive"
        "marchyo-zoom"
        "marchyo-nightlight-toggle"
        "marchyo-idle-toggle"
        "marchyo-screenrecord-toggle"
      ];
      missingBinds = lib.filter (n: !hasBindd n) newBinds;

      # Wrapper packages are installed.
      wrappers = [
        "marchyo-zoom"
        "marchyo-nightlight-toggle"
        "marchyo-idle-toggle"
        "marchyo-screenrecord-toggle"
      ];
      missingPkgs = lib.filter (n: !hasPkg n) wrappers;

      # Monitor focus relocated: no SUPER+comma/period focusmonitor bind remains,
      # the CTRL+ALT+Tab focus bind exists, and comma/period drive emoji/mako.
      focusmonitorMoved = !lib.any (b: lib.hasInfix "SUPER, comma, focusmonitor" b) bind;
      hasCtrlAltMonitor = hasBindd "Focus next monitor, focusmonitor, +1";
      hasEmoji = hasBindd "Emoji picker";
    in
    pkgs.writeText "eval-hyprland-window-management-binds" (
      if missingBinds != [ ] then
        throw "FAIL: missing window-management binds: ${toString missingBinds}"
      else if missingPkgs != [ ] then
        throw "FAIL: missing toggle wrapper packages: ${toString missingPkgs}"
      else if !focusmonitorMoved then
        throw "FAIL: SUPER+comma focusmonitor bind should have been relocated"
      else if !hasCtrlAltMonitor then
        throw "FAIL: CTRL+ALT+Tab monitor-focus bind missing"
      else if !hasEmoji then
        throw "FAIL: emoji picker bind missing"
      else
        "pass"
    );

  # The Super+E editor bind resolves through the $editor variable, which is
  # derived from marchyo.defaults.editor (jotain -> jotain-visual by default,
  # and e.g. vscode -> code when reselected).
  eval-hyprland-editor-bind =
    let
      mkEval =
        extra:
        lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            nixosModules
            (withTestUser (
              lib.recursiveUpdate {
                marchyo.desktop.enable = true;
                home-manager.users.testuser = {
                  imports = [ homeManagerModules ];
                };
              } extra
            ))
          ];
        };
      settingsOf = eval: eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.settings;

      defaultSettings = settingsOf (mkEval { });
      vscodeSettings = settingsOf (mkEval {
        marchyo.defaults.editor = "vscode";
      });

      hasEditorBind = lib.any (b: lib.hasInfix "SUPER, E, Editor, exec, $editor" b) defaultSettings.bindd;
      defaultEditorVar = defaultSettings."$editor";
      vscodeEditorVar = vscodeSettings."$editor";
    in
    pkgs.writeText "eval-hyprland-editor-bind" (
      if !hasEditorBind then
        throw "FAIL: Super+E bind should exec $editor"
      else if defaultEditorVar != "jotain-visual" then
        throw "FAIL: default $editor should be jotain-visual, got ${toString defaultEditorVar}"
      else if vscodeEditorVar != "code" then
        throw "FAIL: $editor for vscode should be code, got ${toString vscodeEditorVar}"
      else
        "pass"
    );

  eval-hyprland-wallpaper-enabled =
    let
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser {
            marchyo.desktop.enable = true;
            home-manager.users.testuser = {
              imports = [ homeManagerModules ];
            };
          })
        ];
      };
      execOnce =
        eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.exec-once;
      hasAwww = lib.any (cmd: lib.hasInfix "awww-daemon --format xrgb" cmd) execOnce;
    in
    pkgs.writeText "eval-hyprland-wallpaper-enabled" (
      if hasAwww then "pass" else throw "FAIL: Hyprland wallpaper startup did not include awww-daemon"
    );

  eval-hyprland-wallpaper-disabled =
    let
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser {
            marchyo = {
              desktop.enable = true;
              theme.wallpaper.enable = false;
            };
            home-manager.users.testuser = {
              imports = [ homeManagerModules ];
            };
          })
        ];
      };
      execOnce =
        eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.exec-once;
      hasAwww = lib.any (cmd: lib.hasInfix "awww-daemon" cmd) execOnce;
    in
    pkgs.writeText "eval-hyprland-wallpaper-disabled" (
      if hasAwww then
        throw "FAIL: Hyprland wallpaper startup included awww-daemon when disabled"
      else
        "pass"
    );
}
