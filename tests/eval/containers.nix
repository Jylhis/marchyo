# Container backend tests, with an emphasis on the security posture of the
# `docker` group. Membership in that group is root-equivalent (the daemon runs
# as root and owns its socket), so it must never be granted implicitly by
# enabling development tools — only on explicit opt-in.
{ lib, ... }:
let
  inDocker = cfg: lib.elem "docker" cfg.users.users.testuser.extraGroups;
  podmanOnly =
    cfg:
    cfg.virtualisation.podman.enable
    && cfg.virtualisation.podman.dockerCompat
    && !cfg.virtualisation.docker.enable
    && !(inDocker cfg);
in
{
  refs = {
    # Default development config: the backend is rootless Podman (dockerCompat),
    # the Docker daemon is NOT enabled, and no `docker` group exists to join. This
    # is the regression guard for the default — enabling development tools must
    # not stand up a rootful daemon or grant passwordless root to the session.
    headless-dev.eval-containers-podman-by-default = podmanOnly;

    # Docker backend opt-in (dev-tweaks: backend = "docker"): selecting the
    # Docker backend enables the daemon, but the user is NOT placed in the
    # root-equivalent `docker` group. This is the regression guard — opting
    # into Docker must not silently grant passwordless root to every process in
    # the session.
    dev-tweaks.eval-containers-no-docker-group-by-default =
      cfg: cfg.virtualisation.docker.enable && !(inDocker cfg);

    # Explicit opt-in (headless-tweaks-2: backend = "docker", dockerGroup =
    # true): only then is the user added to the `docker` group.
    headless-tweaks-2.eval-containers-docker-group-opt-in = inDocker;

    # Podman backend (headless-tweaks-4: backend = "podman", dockerGroup =
    # true): rootless,
    # no Docker daemon, and no `docker` group regardless of the dockerGroup
    # flag (which only applies to the Docker backend).
    headless-tweaks-4.eval-containers-podman-rootless = podmanOnly;
  };

  refConfig = {
    dev-tweaks.marchyo.development.containers.backend = "docker";
    headless-tweaks-2.marchyo.development = {
      enable = true;
      containers.backend = "docker";
      containers.dockerGroup = true;
    };
    headless-tweaks-4.marchyo.development = {
      enable = true;
      containers.backend = "podman";
      # Even with the opt-in set, the docker group is docker-backend only.
      containers.dockerGroup = true;
    };
  };
}
