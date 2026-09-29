{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.marchyo;
  backend = cfg.development.containers.backend;
  mUsers = lib.attrNames (lib.filterAttrs (_name: user: user.enable) config.marchyo.users);
in
{
  config = lib.mkIf cfg.development.enable {

    virtualisation = {
      containers.enable = lib.mkDefault true;
      # Deliberately no root-owned docker-compat socket (dockerSocket): that
      # would re-expose a root daemon socket, defeating the rootless backend.
      podman = lib.mkIf (backend == "podman") {
        enable = lib.mkDefault true;
        defaultNetwork.settings.dns_enable = lib.mkDefault true;
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
        pkgs.podman-tui
      ])
      ++ (lib.optionals (backend == "docker") [ pkgs.lazydocker ]);

    # The Docker daemon runs as root and its socket is root-owned, so the
    # `docker` group is root-equivalent (a group member can mount and write the
    # whole host filesystem as root via a container). Groups are inherited by
    # every session process, so this is granted only when the host explicitly
    # opts in via marchyo.development.containers.dockerGroup.
    # Without it, `sudo docker …` still works. Podman rootless needs no group.
    users.users = lib.mkIf (backend == "docker" && cfg.development.containers.dockerGroup) (
      lib.genAttrs mUsers (_name: {
        extraGroups = [ config.users.groups.docker.name ];
      })
    );
  };
}
