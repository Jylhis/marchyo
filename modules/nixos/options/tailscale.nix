{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.services.tailscale = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable the Tailscale mesh VPN daemon and open the firewall for its traffic.";
    };

    operator = mkOption {
      type = types.nullOr types.str;
      default = null;
      defaultText = lib.literalMD ''
        the first enabled `marchyo.users` entry (by attribute name) when
        `marchyo.desktop.enable` and `marchyo.shell.enable` are set, otherwise
        `null`
      '';
      example = "alice";
      description = ''
        Local user set as the tailnet operator (`tailscale set --operator`),
        applied at boot by the `tailscaled-set` service. The operator can run
        `tailscale up` / `down` without root, which the shell's Control Center
        Tailscale tile needs. Tailscale accepts a single operator. `null`
        leaves the operator unmanaged.
      '';
    };
  };
}
