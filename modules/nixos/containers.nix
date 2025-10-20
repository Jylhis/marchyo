{
  lib,
  pkgs,
  config,
  ...
}:
let
  backend = "docker"; # podman, containerd
  mUsers = builtins.attrNames config.marchyo.users;
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

  users.users = lib.genAttrs mUsers (_name: {
    extraGroups = [
      config.users.groups."${backend}".name
    ];
  });
}
