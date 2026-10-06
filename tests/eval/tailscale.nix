# Tailscale feature toggle (marchyo.services.tailscale.enable, default on).
{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck withTestUser;
in
{
  # Default: tailscale is on, the tailnet interface is trusted, reverse-path
  # filtering is loosened and the WireGuard port is open.
  eval-tailscale-default = testNixOSCheck "tailscale-default" (
    config:
    config.services.tailscale.enable
    && builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces
    && config.networking.firewall.checkReversePath == "loose"
    && builtins.elem config.services.tailscale.port config.networking.firewall.allowedUDPPorts
  ) (withTestUser { });

  # Opt-out: disabling the flag drops the daemon and every firewall relaxation.
  # checkReversePath is deliberately not asserted: nixpkgs (a391f95+) defaults
  # it to "loose" on its own, so it stays "loose" either way — the tailscale
  # module's mkDefault only mirrors the upstream default for explicitness.
  eval-tailscale-disabled =
    testNixOSCheck "tailscale-disabled"
      (
        config:
        !config.services.tailscale.enable
        && !(builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces)
        && !(builtins.elem config.services.tailscale.port config.networking.firewall.allowedUDPPorts)
      )
      (withTestUser {
        marchyo.services.tailscale.enable = false;
      });

  # Desktop + shell on: the primary (first enabled) marchyo user becomes the
  # tailnet operator so the Control Center tile can run `tailscale up/down`.
  eval-tailscale-operator-shell =
    testNixOSCheck "tailscale-operator-shell"
      (
        config:
        config.marchyo.services.tailscale.operator == "testuser"
        && builtins.elem "--operator=testuser" config.services.tailscale.extraSetFlags
        && config.systemd.services ? tailscaled-set
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.shell.enable = true;
      });

  # Shell off: the operator stays unmanaged and no tailscaled-set unit exists.
  eval-tailscale-operator-no-shell =
    testNixOSCheck "tailscale-operator-no-shell"
      (
        config:
        config.marchyo.services.tailscale.operator == null
        && !(builtins.any (lib.hasPrefix "--operator=") config.services.tailscale.extraSetFlags)
        && !(config.systemd.services ? tailscaled-set)
      )
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # An explicit operator wins over the default, and consumer extraSetFlags
  # merge alongside the generated flag.
  eval-tailscale-operator-override =
    testNixOSCheck "tailscale-operator-override"
      (
        config:
        let
          flags = config.services.tailscale.extraSetFlags;
        in
        builtins.elem "--operator=alice" flags
        && !(builtins.elem "--operator=testuser" flags)
        && builtins.elem "--advertise-exit-node" flags
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.shell.enable = true;
        marchyo.services.tailscale.operator = "alice";
        services.tailscale.extraSetFlags = [ "--advertise-exit-node" ];
      });

  # operator = null opts out even with the shell on.
  eval-tailscale-operator-null =
    testNixOSCheck "tailscale-operator-null"
      (config: !(builtins.any (lib.hasPrefix "--operator=") config.services.tailscale.extraSetFlags))
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.shell.enable = true;
        marchyo.services.tailscale.operator = null;
      });
}
