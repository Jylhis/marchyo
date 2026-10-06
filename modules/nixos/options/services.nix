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
          desktop is enabled this installs the LocalSend app through the NixOS
          `programs.localsend` module, which `marchyo share` and the Nautilus
          "Send with LocalSend" script build on. Set to false to keep the
          desktop but skip LocalSend and its open port.
        '';
      };

      openFirewall = mkOption {
        type = types.bool;
        default = true;
        example = false;
        description = ''
          Open TCP and UDP port 53317 on the LAN so other LocalSend devices can
          discover this host and send files to it. Sending with `marchyo share`
          still works with the port closed, through its local subnet scan.
        '';
      };
    };
  };
}
