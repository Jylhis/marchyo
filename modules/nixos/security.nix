# Global (headless-safe): polkit is needed by system services, not just the
# desktop.
{ lib, ... }:
{
  security = {
    polkit = {
      enable = lib.mkDefault true;
    };
  };
}
