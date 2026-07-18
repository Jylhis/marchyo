{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.services = {
    localsend = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable LocalSend file sharing (auto-enabled with the desktop). When the
          desktop is enabled this installs the LocalSend app and opens TCP/UDP
          port 53317 on the LAN so other devices can discover this host. Set to
          false to keep the desktop but skip LocalSend and its open port.
        '';
      };
    };
  };
}
