# Container backend tests, with an emphasis on the security posture of the
# `docker` group. Membership in that group is root-equivalent (the daemon runs
# as root and owns its socket), so it must never be granted implicitly by
# enabling development tools — only on explicit opt-in.
{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck withTestUser;

  inDocker = cfg: lib.elem "docker" cfg.users.users.testuser.extraGroups;
in
{
  # Default development config: the backend is rootless Podman (dockerCompat),
  # the Docker daemon is NOT enabled, and no `docker` group exists to join. This
  # is the regression guard for the default — enabling development tools must
  # not stand up a rootful daemon or grant passwordless root to the session.
  eval-containers-podman-by-default =
    testNixOSCheck "containers-podman-by-default"
      (
        cfg:
        cfg.virtualisation.podman.enable
        && cfg.virtualisation.podman.dockerCompat
        && !cfg.virtualisation.docker.enable
        && !(inDocker cfg)
      )
      (withTestUser {
        marchyo.development.enable = true;
      });

  # Docker backend opt-in: selecting the Docker backend enables the daemon, but
  # the user is NOT placed in the root-equivalent `docker` group. This is the
  # regression guard — opting into Docker must not silently grant passwordless
  # root to every process in the session.
  eval-containers-no-docker-group-by-default =
    testNixOSCheck "containers-no-docker-group-by-default"
      (cfg: cfg.virtualisation.docker.enable && !(inDocker cfg))
      (withTestUser {
        marchyo.development.enable = true;
        marchyo.development.containers.backend = "docker";
      });

  # Explicit opt-in: only when marchyo.development.containers.dockerGroup = true
  # is the user added to the `docker` group.
  eval-containers-docker-group-opt-in =
    testNixOSCheck "containers-docker-group-opt-in" inDocker
      (withTestUser {
        marchyo.development.enable = true;
        marchyo.development.containers.backend = "docker";
        marchyo.development.containers.dockerGroup = true;
      });

  # Podman backend: rootless, no Docker daemon, and no `docker` group regardless
  # of the dockerGroup flag (which only applies to the Docker backend).
  eval-containers-podman-rootless =
    testNixOSCheck "containers-podman-rootless"
      (
        cfg:
        cfg.virtualisation.podman.enable
        && cfg.virtualisation.podman.dockerCompat
        && !cfg.virtualisation.docker.enable
        && !(inDocker cfg)
      )
      (withTestUser {
        marchyo.development.enable = true;
        marchyo.development.containers.backend = "podman";
        # Even with the opt-in set, the docker group is docker-backend only.
        marchyo.development.containers.dockerGroup = true;
      });
}
