# Firmware updates (BIOS, SSD, dock, peripherals) via fwupd / LVFS. Headless-safe.
{ lib, ... }:
{
  # mkDefault so a host can opt out; `fwupdmgr update` drives the actual install.
  services.fwupd.enable = lib.mkDefault true;
}
