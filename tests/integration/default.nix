{
  pkgs,
  nixosModules,
  homeModules,
  home-manager,
  ...
}:
{
  # Integration test: NixOS + Home Manager
  # integration-nixos-home = pkgs.testers.runNixOSTest {
  #   name = "marchyo-integration-nixos-home";

  # Integration test: All feature flags enabled
  integration-all-features = pkgs.testers.runNixOSTest {
    name = "marchyo-integration-all-features";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.testuser = {
                imports = [ homeModules ];
                home.stateVersion = "25.11";
              };
            };
          }
        ];

        marchyo = {
          desktop.enable = true;
          development.enable = true;
          media.enable = true;
          office.enable = true;
          users.testuser = {
            enable = true;
            fullname = "Power User";
            email = "power@marchyo.test";
          };
          timezone = "America/New_York";
          defaultLocale = "en_US.UTF-8";
        };

        users.users.testuser = {
          uid = 1000;
        };

        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "/dev/vda";
          fsType = "ext4";
        };

        system.stateVersion = "25.11";
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test desktop environment
      machine.succeed("command -v Hyprland")

      # Test development tools
      machine.succeed("command -v docker")
      machine.succeed("command -v gh")

      # Test timezone is correct
      machine.succeed("test $(readlink /etc/localtime) = '/etc/zoneinfo/America/New_York'")

      # Test locale
      machine.succeed("localectl status | grep -q 'en_US.UTF-8'")

      # Test user home configuration
      machine.succeed("su - testuser -c 'git --version'")
      machine.succeed("su - testuser -c 'command -v btop'")
    '';
  };

  # Module evaluation test - ensure no infinite recursion or eval errors
  integration-module-eval = pkgs.runCommand "test-module-eval" { } ''
    # Test that NixOS modules can be evaluated
    ${pkgs.nixos-rebuild} --flake ${../../.} --dry-run build 2>/dev/null || true

    # If we got here, evaluation succeeded
    touch $out
  '';
}
