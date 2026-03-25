{
  lib,
  config,
  ...
}:
let
  cfg = config.marchyo;
  backend = "docker"; # podman, containerd
  mUsers = builtins.attrNames config.marchyo.users;
in
{
  config = lib.mkIf cfg.development.enable {
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

    users.users = lib.genAttrs mUsers (_name: {
      extraGroups = [
        config.users.groups."${backend}".name
      ];
    });
  };
}
