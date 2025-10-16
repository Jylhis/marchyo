{
  pkgs,
  homeModules,
  home-manager,
  nixosModules,
  ...
}:
{

  # Git configuration test
  home-git = pkgs.testers.runNixOSTest {
    name = "marchyo-home-git";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              users.testuser = {
                imports = [ homeModules ];
                home.stateVersion = "25.11";
              };
            };
          }
        ];

        users.users.testuser = {
          isNormalUser = true;
          uid = 1000;
        };

        # Define marchyo options for home modules that depend on it
        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };

        system.stateVersion = "25.11";

        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "/dev/vda";
          fsType = "ext4";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test git is available
      machine.succeed("su - testuser -c 'git --version'")

      # Test git LFS is enabled
      machine.succeed("su - testuser -c 'git lfs version'")
    '';
  };

  # Packages test - verify home packages are installed
  home-packages = pkgs.testers.runNixOSTest {
    name = "marchyo-home-packages";

    nodes.machine =
      { ... }:
      {
        imports = [
          nixosModules
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              users.testuser = {
                imports = [ homeModules ];
                home.stateVersion = "25.11";
              };
            };
          }
        ];

        users.users.testuser = {
          isNormalUser = true;
          uid = 1000;
        };

        # Define marchyo options for home modules that depend on it
        marchyo.users.testuser = {
          enable = true;
          fullname = "Test User";
          email = "test@example.com";
        };

        system.stateVersion = "25.11";

        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "/dev/vda";
          fsType = "ext4";
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Test that common packages from modules are available
      machine.succeed("su - testuser -c 'command -v btop'")
      machine.succeed("su - testuser -c 'command -v fastfetch'")
    '';
  };
}
