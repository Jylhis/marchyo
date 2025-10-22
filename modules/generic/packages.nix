{
  lib,
  options,
  ...
}:
{
  programs = {
    zoxide = {
      enable = true;
    };
    nh.enable = true;
  }
  // lib.optionalAttrs (lib.hasAttrByPath [ "trippy" ] options.programs) {
    trippy.enable = true;
  };
}
