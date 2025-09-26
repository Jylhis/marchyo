{ pkgs, ... }:
{
  virtualisation = {
    containers.enable = true;
    podman = {
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enable = true;
      dockerCompat = true;
    };
  };

  environment.systemPackages = with pkgs; [
    buildah
    skopeo
    lazypodman # made in the same spirit like Lazygit,
  ];

  # TODO: Add users to podman group
  # TODO: docker support?
}
