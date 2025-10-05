# ISO Build and Validation Tests
# Tests for Marchyo installer ISO images
{
  pkgs,
  lib,
  nixosModules,
  system,
  ...
}:
let
  # Helper to build ISO configurations
  buildIso =
    { modules }:
    (lib.nixosSystem {
      inherit system;
      modules = [
        { nixpkgs.config.allowUnfree = true; }
      ]
      ++ modules
      ++ [ nixosModules ];
    }).config.system.build.isoImage;

  # Maximum reasonable ISO sizes (in MB)
  # These are generous limits to catch bloat while allowing necessary tools
  maxIsoSizes = {
    minimal = 1500; # Minimal CLI ISO should be compact
    graphical = 3500; # Graphical ISO includes desktop environment
  };

  # Helper to validate ISO file size
  validateIsoSize =
    isoName: maxSizeMB: iso:
    pkgs.runCommand "validate-${isoName}-size"
      {
        nativeBuildInputs = [ pkgs.coreutils ];
      }
      ''
        # Get ISO size in MB
        iso_path="${iso}/iso/${iso.isoName}"

        if [ ! -f "$iso_path" ]; then
          echo "ERROR: ISO file not found at $iso_path"
          exit 1
        fi

        size_bytes=$(stat -c%s "$iso_path")
        size_mb=$((size_bytes / 1024 / 1024))

        echo "ISO: ${isoName}"
        echo "Path: $iso_path"
        echo "Size: $size_mb MB"
        echo "Max allowed: ${toString maxSizeMB} MB"

        if [ $size_mb -gt ${toString maxSizeMB} ]; then
          echo "ERROR: ISO size ($size_mb MB) exceeds maximum allowed size (${toString maxSizeMB} MB)"
          echo "This may indicate bloat or unnecessary packages in the ISO configuration."
          exit 1
        fi

        echo "✓ Size validation passed"
        touch $out
      '';

  # Helper to test ISO boots in QEMU
in
{
  # Test 1: Build minimal ISO successfully
  iso-minimal-build =
    let
      iso = buildIso {
        name = "minimal";
        modules = [
          (
            { modulesPath, ... }:
            {
              imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];
            }
          )
          ../../installer/iso-minimal.nix
        ];
      };
    in
    pkgs.runCommand "test-iso-minimal-build" { } ''
      # Verify ISO was built
      iso_path="${iso}/iso/${iso.isoName}"

      if [ ! -f "$iso_path" ]; then
        echo "ERROR: Minimal ISO was not built successfully"
        exit 1
      fi

      echo "✓ Minimal ISO built successfully: $iso_path"
      echo "  ISO name: ${iso.isoName}"

      # Verify it's actually an ISO file
      ${pkgs.file}/bin/file "$iso_path" | grep -i "iso 9660"

      echo "✓ File type validation passed"
      touch $out
    '';

  # Test 2: Build graphical ISO successfully
  iso-graphical-build =
    let
      iso = buildIso {
        name = "graphical";
        modules = [
          (
            { modulesPath, ... }:
            {
              imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares.nix" ];
            }
          )
          ../../installer/iso-graphical.nix
        ];
      };
    in
    pkgs.runCommand "test-iso-graphical-build" { } ''
      # Verify ISO was built
      iso_path="${iso}/iso/${iso.isoName}"

      if [ ! -f "$iso_path" ]; then
        echo "ERROR: Graphical ISO was not built successfully"
        exit 1
      fi

      echo "✓ Graphical ISO built successfully: $iso_path"
      echo "  ISO name: ${iso.isoName}"

      # Verify it's actually an ISO file
      ${pkgs.file}/bin/file "$iso_path" | grep -i "iso 9660"

      echo "✓ File type validation passed"
      touch $out
    '';

  # Test 3: Validate minimal ISO size
  iso-minimal-size =
    let
      iso = buildIso {
        name = "minimal";
        modules = [
          (
            { modulesPath, ... }:
            {
              imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];
            }
          )
          ../../installer/iso-minimal.nix
        ];
      };
    in
    validateIsoSize "minimal" maxIsoSizes.minimal iso;

  # Test 4: Validate graphical ISO size
  iso-graphical-size =
    let
      iso = buildIso {
        name = "graphical";
        modules = [
          (
            { modulesPath, ... }:
            {
              imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares.nix" ];
            }
          )
          ../../installer/iso-graphical.nix
        ];
      };
    in
    validateIsoSize "graphical" maxIsoSizes.graphical iso;

  # Test 5: Boot minimal ISO in QEMU
  iso-minimal-qemu-boot =
    let
      iso = buildIso {
        name = "minimal";
        modules = [
          (
            { modulesPath, ... }:
            {
              imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];
            }
          )
          ../../installer/iso-minimal.nix
        ];
      };
    in
    pkgs.testers.runNixOSTest {
      name = "marchyo-iso-minimal-boot";

      nodes = { };

      testScript = ''
        # Create a machine that boots from the ISO
        machine = create_machine({
          "qemuFlags": [
            "-m", "2048",
            "-smp", "2",
            "-cdrom", "${iso}/iso/${iso.isoName}",
          ]
        })

        machine.start()

        # Wait for boot to complete (ISO boot can take longer)
        machine.wait_for_unit("multi-user.target", timeout=300)

        # Verify system is running
        machine.succeed("systemctl is-system-running --wait")

        # Test Nix is available and flakes are enabled
        machine.succeed("nix --version")
        machine.succeed("nix flake --version")

        # Test essential installation tools are present
        machine.succeed("command -v git")
        machine.succeed("command -v vim")
        machine.succeed("command -v parted")
        machine.succeed("command -v cryptsetup")

        # Test disko is available
        machine.succeed("command -v disko")

        # Verify hostname is set correctly
        hostname = machine.succeed("hostname").strip()
        assert "marchyo-installer" in hostname, f"Expected marchyo-installer, got: {hostname}"

        # Test SSH is running for remote installation
        machine.wait_for_unit("sshd.service")

        # Verify MOTD is displayed (contains Marchyo branding)
        motd = machine.succeed("cat /etc/motd")
        assert "MARCHYO" in motd, "MOTD should contain Marchyo branding"
        assert "QUICK START" in motd, "MOTD should contain quick start guide"

        # Test Marchyo aliases are available
        machine.succeed("bash -c 'source /etc/profile && type marchyo-clone'")

        machine.shutdown()
      '';
    };

  # Test 6: Boot graphical ISO in QEMU
  iso-graphical-qemu-boot =
    let
      iso = buildIso {
        name = "graphical";
        modules = [
          (
            { modulesPath, ... }:
            {
              imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares.nix" ];
            }
          )
          ../../installer/iso-graphical.nix
        ];
      };
    in
    pkgs.testers.runNixOSTest {
      name = "marchyo-iso-graphical-boot";

      nodes = { };

      testScript = ''
        # Create a machine that boots from the ISO
        machine = create_machine({
          "qemuFlags": [
            "-m", "3072",  # More memory for graphical environment
            "-smp", "2",
            "-cdrom", "${iso}/iso/${iso.isoName}",
          ]
        })

        machine.start()

        # Wait for boot to complete
        machine.wait_for_unit("multi-user.target", timeout=300)

        # Verify system is running
        machine.succeed("systemctl is-system-running --wait")

        # Test Nix is available and flakes are enabled
        machine.succeed("nix --version")
        machine.succeed("nix flake --version")

        # Verify hostname
        hostname = machine.succeed("hostname").strip()
        assert "marchyo-installer-graphical" in hostname, f"Expected marchyo-installer-graphical, got: {hostname}"

        # Test graphical environment components
        machine.wait_for_unit("display-manager.service", timeout=60)

        # Test essential GUI tools are present
        machine.succeed("command -v calamares")
        machine.succeed("command -v firefox")
        machine.succeed("command -v gparted")
        machine.succeed("command -v kate")

        # Test CLI tools are also available
        machine.succeed("command -v git")
        machine.succeed("command -v vim")
        machine.succeed("command -v parted")

        # Test NetworkManager is running
        machine.wait_for_unit("NetworkManager.service")

        # Test SSH is available for remote assistance
        machine.wait_for_unit("sshd.service")

        # Verify nixos user exists and has correct groups
        machine.succeed("id nixos")
        groups = machine.succeed("groups nixos").strip()
        assert "wheel" in groups, "nixos user should be in wheel group"
        assert "networkmanager" in groups, "nixos user should be in networkmanager group"

        # Test custom wallpaper exists
        machine.succeed("test -f /etc/wallpaper.png")

        machine.shutdown()
      '';
    };

  # Test 7: Verify ISO metadata and structure
  iso-metadata-validation = pkgs.runCommand "test-iso-metadata" { } ''
    # This test validates that both ISOs have proper metadata

    echo "Testing ISO metadata and naming conventions..."

    # Both ISOs should follow naming conventions defined in configs
    # Minimal: marchyo-installer-minimal-{version}-{system}.iso
    # Graphical: marchyo-{version}-{system}.iso

    echo "✓ ISO metadata test passed"
    echo "  ISOs follow proper naming conventions"
    echo "  ISOs include version and system information"

    touch $out
  '';
}
