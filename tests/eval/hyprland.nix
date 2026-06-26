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
            marchyo = {
              desktop.enable = true;
              keybindingsHelp.enable = false;
            };
            home-manager.users.testuser = {
              imports = [ homeManagerModules ];
            };
          })
        ];
      };
      bindd =
        eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.bindd;
      hasBind = lib.any (b: lib.hasInfix "marchyo-keybindings" b) bindd;
    in
    pkgs.writeText "eval-hyprland-keybindings-cheatsheet-disabled" (
      if hasBind then throw "FAIL: keybindings cheat sheet bind present when disabled" else "pass"
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
