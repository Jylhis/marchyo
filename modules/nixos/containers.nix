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
      containers.enable = true;
      # Rootless Podman: daemonless, user-namespaced, no privileged group. The
      # `docker` CLI is provided via dockerCompat. Deliberately no root-owned
      # docker-compat socket (dockerSocket) — that would re-expose a root
      # daemon socket, defeating the point of the rootless backend.
      podman = lib.mkIf (backend == "podman") {
        enable = true;
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

    # The Docker daemon runs as root and its socket is root-owned, so the
    # `docker` group is root-equivalent (a group member can mount and write the
    # whole host filesystem as root via a container). Groups are inherited by
    # every session process, so this is not granted by default — only when the
    # host explicitly opts in via marchyo.development.containers.dockerGroup.
    # Without it, `sudo docker …` still works. Podman rootless needs no group.
    users.users = lib.mkIf (backend == "docker" && cfg.development.containers.dockerGroup) (
      lib.genAttrs mUsers (_name: {
        extraGroups = [ config.users.groups.docker.name ];
      })
    );
  };
}
