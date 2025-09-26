{ lib, pkgs, ... }:
let
  usePodman = false;
in
{

  virtualisation = {
    containers.enable = true;
    podman = lib.mkIf usePodman {
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enable = true;
      dockerCompat = true;
    };

    docker = lib.mkIf (!usePodman) {

      enable = true;
      daemon.settings.features.cdi = true;

    };
  };

  environment.systemPackages =
    with pkgs;
    [
      buildah
      skopeo
    ]
    ++ (lib.optionals usePodman [
      pkgs.lazypodman # made in the same spirit like Lazygit
    ])
    ++ (lib.optionals (!usePodman) [ pkgs.lazydocker ]);

  # TODO: Add users to podman/docker group
}
