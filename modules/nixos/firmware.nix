# Global (headless-safe): firmware updates via fwupd / the Linux Vendor
# Firmware Service. Applies BIOS, SSD, dock, and peripheral firmware.
{ lib, ... }:
{
  # mkDefault so a host can opt out. `fwupdmgr get-updates` / `fwupdmgr update`
  # (or the shell's update flow) drives the actual install.
  services.fwupd.enable = lib.mkDefault true;
}
