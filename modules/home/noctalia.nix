{ lib, ... }:
{
  config = {
    programs.noctalia.enable = lib.mkDefault true;
  };
}
