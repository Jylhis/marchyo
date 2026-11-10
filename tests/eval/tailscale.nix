# Tailscale (services.tailscale.enable, on by default through marchyo).
{ lib, ... }:
let
  noOperatorFlag =
    config: !(builtins.any (lib.hasPrefix "--operator=") config.services.tailscale.extraSetFlags);
in
{
  refs = {
    # Default: tailscale is on, the tailnet interface is trusted, reverse-path
    # filtering is loosened and the WireGuard port is open.
    headless.eval-tailscale-default =
      config:
      config.services.tailscale.enable
      && builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces
      && config.networking.firewall.checkReversePath == "loose"
      && builtins.elem config.services.tailscale.port config.networking.firewall.allowedUDPPorts;

    # Opt-out (headless-tweaks-3: services.tailscale.enable = false): disabling
    # the service drops the daemon and every firewall relaxation.
    # checkReversePath is deliberately not asserted: nixpkgs (a391f95+) defaults
    # it to "loose" on its own, so it stays "loose" either way — the tailscale
    # module's mkDefault only mirrors the upstream default for explicitness.
    headless-tweaks-3.eval-tailscale-disabled =
      config:
      !config.services.tailscale.enable
      && !(builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces)
      && !(builtins.elem config.services.tailscale.port config.networking.firewall.allowedUDPPorts);

    # Desktop + shell on: the primary (first enabled) marchyo user becomes the
    # tailnet operator so the Control Center tile can run `tailscale up/down`.
    desktop.eval-tailscale-operator-shell =
      config:
      config.marchyo.services.tailscale.operator == "testuser"
      && builtins.elem "--operator=testuser" config.services.tailscale.extraSetFlags
      && config.systemd.services ? tailscaled-set;

    # Shell off: the operator stays unmanaged and no tailscaled-set unit exists.
    desktop-shell-off.eval-tailscale-operator-no-shell =
      config:
      config.marchyo.services.tailscale.operator == null
      && noOperatorFlag config
      && !(config.systemd.services ? tailscaled-set);

    # An explicit operator wins over the default, and consumer extraSetFlags
    # merge alongside the generated flag (desktop-tweaks: operator = "alice",
    # extraSetFlags = [ "--advertise-exit-node" ]).
    desktop-tweaks.eval-tailscale-operator-override =
      config:
      let
        flags = config.services.tailscale.extraSetFlags;
      in
      builtins.elem "--operator=alice" flags
      && !(builtins.elem "--operator=testuser" flags)
      && builtins.elem "--advertise-exit-node" flags;

    # operator = null opts out even with the shell on (desktop-tweaks-2).
    desktop-tweaks-2.eval-tailscale-operator-null = noOperatorFlag;
  };

  refConfig = {
    headless-tweaks-3.services.tailscale.enable = false;
    desktop-tweaks = {
      marchyo.services.tailscale.operator = "alice";
      services.tailscale.extraSetFlags = [ "--advertise-exit-node" ];
    };
    desktop-tweaks-2.marchyo.services.tailscale.operator = null;
  };
}
