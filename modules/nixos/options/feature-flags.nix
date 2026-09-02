{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo = {
    desktop = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable desktop environment (Hyprland, Wayland, fonts, etc.)";
      };
    };

    development = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable development tools (Podman, buildah, gh, etc.)";
      };

      containers = {
        backend = mkOption {
          type = types.enum [
            "podman"
            "docker"
          ];
          default = "podman";
          description = ''
            Container backend enabled by `marchyo.development.enable`.

            - `"podman"` (default) runs Podman rootless: daemonless, in a user
              namespace, needing no privileged group. The `docker` command is
              provided as a compatibility shim (`dockerCompat`), so most
              workflows keep working without granting any host-level privilege.
            - `"docker"` runs the classic Docker daemon as root. `docker`
              commands require `sudo` unless the invoking user is a member of
              the `docker` group — see
              `marchyo.development.containers.dockerGroup`.
          '';
        };

        dockerGroup = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to add Marchyo users to the `docker` group when the Docker
            backend is in use.

            Disabled by default because membership in the `docker` group is
            equivalent to passwordless root on the host. The Docker daemon runs
            as root and owns its socket; any process that can reach that socket
            can start a container that bind-mounts and writes the entire host
            filesystem as root. Because supplementary groups are inherited by
            every process in the user's session, granting this exposes root to
            all code the user runs — browsers, editors, AI agents, npm scripts,
            build tools — not just to Docker itself.

            This flag only applies when you have opted into the Docker backend
            (`marchyo.development.containers.backend = "docker"`); the default
            rootless Podman backend needs no group at all. Leave this off (the
            recommended default): the daemon still runs and `sudo docker …`
            works. Enable this only on machines where you have accepted that
            every session process effectively has root.
          '';
        };
      };
    };

    media = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable media applications (Spotify, MPV, etc.)";
      };
    };

    office = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable office applications (LibreOffice, Papers, etc.)";
      };
    };
  };
}
