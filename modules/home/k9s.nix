{
  lib,
  config,
  osConfig,
  ...
}:
{
  config = {
    programs.k9s = {
      enable = true;
    };
  };
}
