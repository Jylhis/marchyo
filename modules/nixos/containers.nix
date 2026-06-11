{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.marchyo;
  mUsers = lib.attrNames (lib.filterAttrs (_name: user: user.enable) config.marchyo.users);
in
{
  config = lib.mkIf cfg.development.enable {

    virtualisation = {
      containers.enable = true;

      docker = {
        # mkDefault so a consumer can flip to false (or to podman's
        # dockerCompat) without a priority conflict; development-config.nix
        # also sets this at mkDefault, so the two merge cleanly.
        enable = lib.mkDefault true;
        daemon.settings.features.cdi = true;
      };
    };

    environment.systemPackages = with pkgs; [
      buildah
      skopeo
    ];

    users.users = lib.genAttrs mUsers (_name: {
      extraGroups = [
        config.users.groups.docker.name
      ];
    });
  };
}
