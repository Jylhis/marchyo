# Feature-gated: marchyo.services.tailscale.enable.
{ config, lib, ... }:
let
  cfg = config.marchyo;
  tsCfg = cfg.services.tailscale;
  enabledUsers = lib.attrNames (lib.filterAttrs (_name: user: user.enable) cfg.users);
in
{
  config = lib.mkIf tsCfg.enable (
    lib.mkMerge [
      {
        services.tailscale.enable = lib.mkDefault true;

        networking.firewall = {
          trustedInterfaces = [ "tailscale0" ];
          # Tailscale routes packets asymmetrically; strict reverse-path
          # filtering would drop them.
          checkReversePath = lib.mkDefault "loose";
          # Allow direct (non-DERP) WireGuard connections.
          allowedUDPPorts = [ config.services.tailscale.port ];
        };

        # Appended, so consumer extraSetFlags merge alongside it.
        services.tailscale.extraSetFlags = lib.optional (
          tsCfg.operator != null
        ) "--operator=${tsCfg.operator}";
      }

      # The shell's Control Center tile runs `tailscale up/down` as the session
      # user, so default the operator to the primary marchyo user.
      (lib.mkIf (cfg.desktop.enable && cfg.shell.enable && enabledUsers != [ ]) {
        marchyo.services.tailscale.operator = lib.mkDefault (builtins.head enabledUsers);
      })
    ]
  );
}
