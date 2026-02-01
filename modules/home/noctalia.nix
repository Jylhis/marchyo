{ lib, ... }:
{
  config = {
    programs.noctalia-shell.enable = lib.mkDefault true;
  };
}
