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
    programs = {
      git = {
        enable = lib.mkDefault true;
        lfs.enable = lib.mkDefault true;
      };
      bash.completion.enable = lib.mkDefault true;
      direnv = {
        enable = lib.mkDefault true;
        nix-direnv.enable = lib.mkDefault true;
      };
    };

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
          swtpm.enable = lib.mkDefault true;
        };
      };
    };

    environment.systemPackages = with pkgs; [
      git
      gh

      gnumake
      cmake
      gcc
      pkg-config

      docker-compose
      lazydocker

      virt-manager
      virt-viewer

      sqlite

      curl
      wget
      netcat
      nmap
      tcpdump

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

    documentation.dev.enable = lib.mkDefault true;
  };
}
