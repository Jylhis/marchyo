{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprHasBind hyprEntriesText;
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
      hyprlandConfig = eval.config.home-manager.users.testuser.xdg.configFile."hypr/hyprland.lua".source;
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

        # A clean run prints "config ok"; require it explicitly rather than
        # trusting the exit code, which is 0 even when errors are printed.
        if ! grep -q -F 'config ok' "$log"; then
          echo "FAIL: hyprland --verify-config did not report 'config ok'" >&2
          exit 1
        fi

        # Also grep for error markers. The Lua renderer makes this much
        # stronger than the old hyprlang path: a typo'd `hl.*` name is a nil
        # call that aborts the whole config load instead of being skipped.
        # Keep the patterns specific - the debug preamble legitimately says
        # "Config is lua, loading lua mgr", so a bare /lua/ would false-positive.
        if grep -E -i \
             -e 'invalid dispatcher' \
             -e 'config option <[^>]+> does not exist' \
             -e '^\s*error' \
             -e 'parse error' \
             -e 'attempt to (call|index) a nil value' \
             -e 'lua error' \
             -e 'error loading' \
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
      hasBind = lib.hasInfix "marchyo keybindings" (
        hyprEntriesText hm.wayland.windowManager.hyprland.settings.bind
      );
      hasPkg = lib.any (p: lib.hasInfix "fzf" (p.name or "")) hm.home.packages;
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
      hasBind = lib.hasInfix "marchyo keybindings" (
        hyprEntriesText eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bind
      );
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
      bind = hm.wayland.windowManager.hyprland.settings.bind;
      bindText = hyprEntriesText bind;
      hasBindText = needle: lib.hasInfix needle bindText;
      hasPkg = name: lib.any (p: lib.hasInfix name (p.name or "")) hm.home.packages;

      # New window-management dispatchers are present, in their Lua spellings.
      newBinds = [
        "hl.dsp.group.toggle()"
        "into_group"
        "follow = false"
        "hl.dsp.workspace.move("
        "hl.dsp.window.resize({ x = -100"
        "marchyo zoom in"
        "marchyo toggle nightlight"
        "marchyo toggle idle"
        "marchyo toggle caffeine"
        "marchyo capture record"
      ];
      missingBinds = lib.filter (n: !hasBindText n) newBinds;

      # All former wrapper scripts are absorbed into the marchyo CLI; the
      # recorder tool closure remains.
      wrappers = [
        "gpu-screen-recorder"
      ];
      missingPkgs = lib.filter (n: !hasPkg n) wrappers;

      # Monitor focus relocated: no SUPER+comma/period focusmonitor bind remains,
      # the CTRL+ALT+Tab focus bind exists, and comma/period drive emoji/mako.
      focusmonitorMoved = !(hyprHasBind bind "SUPER + comma" "hl.dsp.focus({ monitor");
      hasCtrlAltMonitor = hyprHasBind bind "CTRL + ALT + TAB" ''hl.dsp.focus({ monitor = "+1" })'';
      hasEmoji = hasBindText "Emoji picker";
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

  # The Super+E editor bind resolves through the `editor` Lua local, which is
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

      hasEditorBind = hyprHasBind defaultSettings.bind "SUPER + E" "hl.dsp.exec_cmd(editor)";
      defaultEditorVar = defaultSettings.editor._var;
      vscodeEditorVar = vscodeSettings.editor._var;
    in
    pkgs.writeText "eval-hyprland-editor-bind" (
      if !hasEditorBind then
        throw "FAIL: Super+E bind should exec the editor local"
      else if defaultEditorVar != "jotain-visual" then
        throw "FAIL: default editor local should be jotain-visual, got ${toString defaultEditorVar}"
      else if vscodeEditorVar != "code" then
        throw "FAIL: editor local for vscode should be code, got ${toString vscodeEditorVar}"
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
      startup = hyprEntriesText eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.on;
      hasAwww = lib.hasInfix "awww-daemon --format xrgb" startup;
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
      startup = hyprEntriesText eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.on;
      hasAwww = lib.hasInfix "awww-daemon" startup;
    in
    pkgs.writeText "eval-hyprland-wallpaper-disabled" (
      if hasAwww then
        throw "FAIL: Hyprland wallpaper startup included awww-daemon when disabled"
      else
        "pass"
    );
}
