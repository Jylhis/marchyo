{ lib, pkgs, ... }:
let
  backend = "docker"; # podman, containerd
in
{

  virtualisation = {
    containers.enable = true;
    podman = lib.mkIf (backend == "podman") {
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enable = true;
      dockerCompat = true;
    };

    docker = lib.mkIf (backend == "docker") {
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
    ++ (lib.optionals (backend == "podman") [
      pkgs.lazypodman # made in the same spirit like Lazygit
    ])
    ++ (lib.optionals (backend == "docker") [ pkgs.lazydocker ]);

  # TODO: Add users to podman/docker group
}
