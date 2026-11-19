{ lib, osConfig, ... }:
let
  mc = osConfig.marchyo;
in
{
  config = lib.mkIf (
    mc.security.hardening.firewall.enable
    && mc.security.hardening.firewall.ui.enable
    && mc.desktop.enable
  ) { services.opensnitch-ui.enable = true; };
}
