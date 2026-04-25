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
        ${hyprland}/bin/hyprland --verify-config --config ${hyprlandConfig}

        echo "DONE"
        touch $out
      '';
}
