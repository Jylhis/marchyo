# Network option declarations (implementation: modules/nixos/network.nix and
# modules/home/captive-portal.nix).
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.network.connectivityCheck = {
    enable = mkOption {
      type = types.bool;
      default = config.marchyo.desktop.enable;
      defaultText = lib.literalExpression "config.marchyo.desktop.enable";
      description = ''
        Periodic NetworkManager connectivity check. It lets the shell detect
        captive portals and offers a sign-in window (`marchyo network portal`).
        Every `interval` seconds NetworkManager requests `uri` over plain HTTP,
        so the configured host sees your public IP. Set false to send no
        probes (captive portals are then not detected).
      '';
    };

    uri = mkOption {
      type = types.str;
      default = "http://nmcheck.gnome.org/check_network_status.txt";
      description = ''
        URL NetworkManager requests to decide whether the network is online.
        It must stay plain HTTP so that a captive portal can intercept it; the
        sign-in window opens the same URL.
      '';
    };

    response = mkOption {
      type = types.str;
      default = "NetworkManager is online";
      description = ''
        Text the endpoint returns when the network is online. An empty string
        accepts any answer that carries the `X-NetworkManager-Status: online`
        header (for endpoints that reply 204).
      '';
    };

    interval = mkOption {
      type = types.ints.positive;
      default = 300;
      description = "Seconds between connectivity checks.";
    };
  };
}
