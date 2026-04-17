# Development configuration module
# Automatically enables development tools and services when marchyo.development.enable is true
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf cfg.development.enable {
    # Development shell programs
    programs = {
      git = {
        enable = true;
        lfs.enable = true;
      };
      bash.completion.enable = true;
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
    };

    # Virtualization for development
    virtualisation = {
      docker = lib.mkIf (!config.virtualisation.podman.enable) {
        enable = lib.mkDefault true;
        enableOnBoot = lib.mkDefault false;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };
      libvirtd = {
        enable = lib.mkDefault true;
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = false;
          swtpm.enable = true;
        };
      };
    };

    # Development tools (shell/tui/container tools are in packages.nix)
    environment.systemPackages = with pkgs; [
      # Build tools
      gnumake
      cmake
      gcc
      pkg-config

      # Virtual machines
      virt-manager
      virt-viewer

      # Database clients
      sqlite

      # Network debugging
      curl
      wget
      netcat
      nmap
      tcpdump

      # Development utilities
      jq
      yq
      tree
    ];

    # Enable KVM modules
    boot.kernelModules = [
      "kvm-intel"
      "kvm-amd"
    ];

    # Development documentation
    documentation.dev.enable = true;
  };
}
