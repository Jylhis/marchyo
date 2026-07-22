# Evaluation tests for modules/home/omarchy-binds.nix (OMARCHY_PARITY.md
# Phase 2: monitor controls, connectivity TUIs, app-launch binds).
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

  evalWith =
    extra:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };

  hmFor = eval: eval.config.home-manager.users.testuser;
  binds = hm: hm.wayland.windowManager.hyprland.settings.bindd or [ ];
  hasBind = hm: s: lib.any (b: lib.hasInfix s b) (binds hm);
  hasPackage = hm: n: lib.any (p: lib.getName p == n) hm.home.packages;
in
{
  # Desktop + development on: monitor-control, connectivity, and app-launch
  # binds are all present, and the backing scripts + tmux land in the profile.
  eval-omarchy-binds-enabled =
    let
      hm = hmFor (evalWith {
        marchyo.desktop.enable = true;
        marchyo.development.enable = true;
      });
    in
    pkgs.writeText "eval-omarchy-binds-enabled" (
      if
        hasBind hm "SUPER, backslash, Cycle monitor scale, exec, marchyo monitor scale-cycle"
        && hasBind hm "SUPER CTRL, Delete, Toggle laptop display, exec, marchyo monitor laptop-toggle"
        && hasBind hm "SUPER CTRL, A, Audio mixer, exec, $terminal --class=org.omarchy.wiremix -e wiremix"
        && hasBind hm "SUPER CTRL, B, Bluetooth manager, exec, $terminal --class=org.omarchy.bluetui -e bluetui"
        && hasBind hm "SUPER CTRL, W, Wi-Fi manager, exec, $terminal --class=org.omarchy.nmtui -e nmtui"
        && hasBind hm "SUPER ALT, return, tmux Work session, exec, $terminal -e tmux new -A -s Work"
        && hasBind hm "SUPER ALT, D, Docker TUI, exec, $terminal --class=org.omarchy.terminal -e lazydocker"
        && hasBind hm "SUPER ALT SHIFT, F, File manager at terminal cwd, exec, marchyo launch file-manager"
        && hasPackage hm "xdg-utils"
        && hasPackage hm "tmux"
      then
        "pass"
      else
        throw "FAIL: desktop+development enabled but an omarchy-binds keybinding or backing package is missing"
    );

  # Development off (the default): the Docker TUI bind follows the same gate as
  # lazydocker itself, while the rest of the binds stay present.
  eval-omarchy-binds-no-development =
    let
      hm = hmFor (evalWith {
        marchyo.desktop.enable = true;
      });
    in
    pkgs.writeText "eval-omarchy-binds-no-development" (
      if hasBind hm "marchyo monitor scale-cycle" && !(hasBind hm "lazydocker") then
        "pass"
      else
        throw "FAIL: development disabled but the Docker TUI bind is present (or the other binds are missing)"
    );

  # Desktop off (default): none of the omarchy-binds contributions leak.
  eval-omarchy-binds-disabled =
    let
      hm = hmFor (evalWith { });
    in
    pkgs.writeText "eval-omarchy-binds-disabled" (
      if
        !(hasBind hm "marchyo monitor scale-cycle")
        && !(hasBind hm "marchyo monitor laptop-toggle")
        && !(hasBind hm "marchyo launch file-manager")
        && !(hasPackage hm "tmux")
      then
        "pass"
      else
        throw "FAIL: desktop disabled but an omarchy-binds keybinding or package is present"
    );
}
