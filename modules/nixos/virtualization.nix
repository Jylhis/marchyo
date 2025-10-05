{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    mkIf
    mkMerge
    mkDefault
    types
    ;
  inherit ((import ../../lib { inherit lib; })) mapListToAttrs;
  cfg = config.marchyo.virtualization;
  mUsers = builtins.attrNames config.marchyo.users;
in
{
  options.marchyo.virtualization = {
    enable = mkOption {
      type = types.bool;
      # Auto-enable when development.enable is true
      default = config.marchyo.development.enable;
      defaultText = "config.marchyo.development.enable";
      description = ''
        Enable virtualization support for VMs and containers.
        Automatically enabled when marchyo.development.enable is true.
      '';
    };

    enableDocker = mkOption {
      type = types.bool;
      # Default to enabled when development.enable is true
      default = config.marchyo.development.enable;
      defaultText = "config.marchyo.development.enable";
      description = ''
        Enable Docker container runtime.
        Automatically enabled when marchyo.development.enable is true.
      '';
    };

    enablePodman = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable Podman container runtime.
        Podman is a daemonless container engine that can run rootless containers.
      '';
    };
  };

  config = mkMerge [
    # VM Virtualization (libvirt/QEMU/KVM)
    (mkIf cfg.enable {
      # Enable libvirtd for managing VMs
      virtualisation.libvirtd = {
        enable = true;

        # QEMU configuration
        qemu = {
          # Run QEMU as user instead of root for better security
          runAsRoot = false;

          # Enable UEFI support with OVMF firmware
          ovmf = {
            enable = true;
            packages = [ pkgs.OVMFFull.fd ];
          };

          # Enable SPICE and USB redirection for better VM interaction
          swtpm.enable = true; # TPM emulation
          verbatimConfig = ''
            # Enable USB redirection for better device passthrough
            user = "root"
            group = "libvirtd"
          '';
        };

        # Enable SPICE USB redirection
        # Allows USB devices to be passed through to VMs
        allowedBridges = [
          "virbr0"
          "br0"
        ];
      };

      # Enable required kernel modules for KVM virtualization
      boot.kernelModules = [
        "kvm-intel" # For Intel CPUs
        "kvm-amd" # For AMD CPUs
      ];

      # Install virtualization management tools
      environment.systemPackages = with pkgs; [
        virt-manager # GUI for managing VMs
        virt-viewer # VM console viewer
        spice # SPICE protocol support
        spice-gtk # SPICE client libraries
        spice-protocol # SPICE protocol headers
        win-virtio # Windows VirtIO drivers
        win-spice # Windows SPICE drivers
      ];

      # Add users to libvirtd group for VM management
      users.users = mapListToAttrs mUsers (_name: {
        extraGroups = [ "libvirtd" ];
      });

      # Enable dconf for virt-manager settings persistence
      programs.dconf.enable = true;
    })

    # Docker Container Runtime
    (mkIf (cfg.enable && cfg.enableDocker) {
      virtualisation = {
        containers.enable = true;

        docker = {
          enable = true;

          # Enable CDI (Container Device Interface) for better device support
          daemon.settings.features.cdi = true;

          # Enable automatic storage cleanup
          autoPrune = {
            enable = mkDefault true;
            dates = mkDefault "weekly";
          };
        };
      };

      # Install Docker-related tools
      environment.systemPackages = with pkgs; [
        docker-compose # Docker Compose for multi-container apps
        lazydocker # Terminal UI for Docker
        buildah # Alternative container builder
        skopeo # Container image management
      ];

      # Add users to docker group
      users.users = mapListToAttrs mUsers (_name: {
        extraGroups = [ "docker" ];
      });
    })

    # Podman Container Runtime
    (mkIf (cfg.enable && cfg.enablePodman) {
      virtualisation = {
        containers.enable = true;

        podman = {
          enable = true;

          # Enable Docker compatibility layer
          dockerCompat = true;
          dockerSocket.enable = true;

          # Enable DNS in containers
          defaultNetwork.settings.dns_enable = true;

          # Enable automatic storage cleanup
          autoPrune = {
            enable = mkDefault true;
            dates = mkDefault "weekly";
          };
        };
      };

      # Install Podman-related tools
      environment.systemPackages = with pkgs; [
        lazypodman # Terminal UI for Podman
        buildah # Container builder (works well with Podman)
        skopeo # Container image management
        podman-compose # Docker Compose compatibility for Podman
      ];

      # Add users to podman group if it exists
      users.users = mapListToAttrs mUsers (_name: {
        extraGroups = lib.optionals (config.users.groups ? podman) [ "podman" ];
      });
    })
  ];
}
