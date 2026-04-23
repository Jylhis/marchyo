{
  lib,
  pkgs,
  options,
  ...
}:
{
  config =
    if (options ? programs && options.programs ? git) then
      {
        programs.git = {
          enable = true;
          package = lib.mkDefault pkgs.gitFull;
          lfs.enable = true;
        };
      }
    else
      { };
}
