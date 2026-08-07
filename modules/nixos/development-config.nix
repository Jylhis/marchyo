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

    # Development tools
    environment.systemPackages = with pkgs; [
      # Version control
      git
      gh

      # Build tools
      gnumake
      cmake
      gcc
      pkg-config

      # Container tools
      docker-compose
      lazydocker

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
      ripgrep
      fd
      eza
    ];

    # Enable KVM for the host CPU vendor only. Loading both makes
    # systemd-modules-load fail on every boot for the vendor that is absent
    # ("Failed to insert module 'kvm_intel': Operation not supported").
    # hardware.cpu.<vendor>.updateMicrocode is the conventional vendor signal,
    # set by nixos-hardware's common-cpu-{amd,intel} modules.
    boot.kernelModules =
      lib.optional config.hardware.cpu.amd.updateMicrocode "kvm-amd"
      ++ lib.optional config.hardware.cpu.intel.updateMicrocode "kvm-intel";

    # Development documentation
    documentation.dev.enable = true;
  };
}
