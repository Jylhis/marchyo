# Tailscale feature toggle (marchyo.services.tailscale.enable, default on).
{ helpers, ... }:
let
  inherit (helpers) testNixOSCheck withTestUser;
in
{
  # Default: tailscale is on, the tailnet interface is trusted, reverse-path
  # filtering is loosened and the WireGuard port is open.
  eval-tailscale-default =
    testNixOSCheck "tailscale-default"
      (
        config:
        config.services.tailscale.enable
        && builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces
        && config.networking.firewall.checkReversePath == "loose"
        && builtins.elem config.services.tailscale.port config.networking.firewall.allowedUDPPorts
      )
      (withTestUser { });

  # Opt-out: disabling the flag drops the daemon and every firewall relaxation.
  eval-tailscale-disabled =
    testNixOSCheck "tailscale-disabled"
      (
        config:
        !config.services.tailscale.enable
        && !(builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces)
        && config.networking.firewall.checkReversePath != "loose"
        && !(builtins.elem config.services.tailscale.port config.networking.firewall.allowedUDPPorts)
      )
      (withTestUser { marchyo.services.tailscale.enable = false; });
}
